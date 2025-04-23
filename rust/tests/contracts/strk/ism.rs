use cainome::cairo_serde::ContractAddress;
use futures::{stream::FuturesUnordered, StreamExt};
use starknet::{accounts::Account, core::types::Felt, macros::felt};

use super::bind::multisig_ism::messageid_multisig_ism;
use super::bind::routing::domain_routing_ism;
use crate::validator::{self, TestValidators};

use super::{deploy_contract, types::Codes, StarknetAccount};

#[derive(Clone)]
pub enum Ism {
    Routing(Vec<(u32, Self)>),

    Multisig {
        validators: validator::TestValidators,
    },

    Aggregate {
        isms: Vec<Self>,
        threshold: u8,
    },

    #[allow(dead_code)]
    Mock,
}

impl Ism {
    pub fn routing(isms: Vec<(u32, Self)>) -> Self {
        Self::Routing(isms)
    }

    pub fn multisig(validators: validator::TestValidators) -> Self {
        Self::Multisig { validators }
    }
}

impl Ism {
    async fn deploy_mock(codes: &Codes, deployer: &StarknetAccount) -> eyre::Result<Felt> {
        let res = deploy_contract(codes.test_mock_ism, vec![], deployer).await;
        Ok(res.0)
    }

    async fn deploy_multisig(
        codes: &Codes,
        set: validator::TestValidators,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<Felt> {
        let params: Vec<Felt> = std::iter::once(owner.address())
            .chain(
                set.validators
                    .iter()
                    .map(|validator| validator.eth_addr().0),
            )
            .collect();
        let res: (Felt, starknet::core::types::InvokeTransactionResult) =
            deploy_contract(codes.ism_multisig, params, deployer).await;

        let contract = messageid_multisig_ism::new(res.0, owner);
        Ok(res.0)
    }

    async fn deploy_routing(
        codes: &Codes,
        isms: Vec<(u32, Self)>,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<Felt> {
        let res = deploy_contract(codes.ism_routing, vec![owner.address()], deployer).await;

        let futures = FuturesUnordered::new();

        for i in isms.iter() {
            let future = async move {
                <Ism as Clone>::clone(&i.1)
                    .deploy(codes, owner, deployer)
                    .await
            };
            futures.push(future);
        }

        let results = futures.collect::<Vec<_>>().await;

        let modules: Vec<_> = results
            .iter()
            .map(|a| ContractAddress(*a.as_ref().expect("Failed to deploy ISM")))
            .collect();

        let contract = domain_routing_ism::new(res.0, owner);
        contract
            .initialize(&isms.iter().map(|i| i.0).collect::<Vec<_>>(), &modules)
            .send()
            .await?;

        Ok(res.0)
    }

    async fn deploy_aggregate(
        codes: &Codes,
        isms: Vec<Self>,
        threshold: u8,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<Felt> {
        let futures = FuturesUnordered::new();

        for i in isms.iter() {
            let future = async move {
                <Ism as Clone>::clone(&i)
                    .deploy(codes, owner, deployer)
                    .await
            };
            futures.push(future);
        }

        let results = futures.collect::<Vec<_>>().await;

        let ism_addrs: Vec<_> = results.iter().map(|a| *a.as_ref().unwrap()).collect();

        let res = deploy_contract(codes.ism_aggregate, ism_addrs, deployer).await;

        Ok(res.0)
    }

    pub async fn deploy(
        self,
        codes: &Codes,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<Felt> {
        match self {
            Self::Mock => Self::deploy_mock(codes, deployer).await,
            Self::Multisig { validators: set } => {
                Self::deploy_multisig(codes, set, owner, deployer).await
            }
            Self::Aggregate { isms, threshold } => {
                Self::deploy_aggregate(codes, isms, threshold, owner, deployer).await
            }
            Self::Routing(isms) => Self::deploy_routing(codes, isms, owner, deployer).await,
        }
    }
}

pub fn prepare_routing_ism(info: Vec<(u32, TestValidators)>) -> Ism {
    let mut isms = vec![];

    for (domain, set) in info {
        isms.push((domain, Ism::multisig(set)));
    }

    Ism::routing(isms)
}
