use std::collections::BTreeMap;

use starknet::core::types::FieldElement;

use super::{deploy_contract, types::Codes, StarknetAccount};
use eyre::Result;

#[allow(dead_code)]
pub enum Hook {
    Mock {
        gas: FieldElement,
    },

    Merkle {},
    Igp(u32),

    Pausable {},

    Routing {
        routes: Vec<(u32, Self)>,
    },

    RoutingCustom {
        routes: Vec<(u32, Self)>,
        custom_hooks: BTreeMap<(u32, FieldElement), Self>,
    },

    RoutingFallback {
        routes: Vec<(u32, Self)>,
        fallback_hook: Box<Self>,
    },

    Aggregate {
        hooks: Vec<Self>,
    },
}

#[allow(dead_code)]
impl Hook {
    pub fn mock(gas: FieldElement) -> Self {
        Self::Mock { gas }
    }

    pub fn routing(routes: Vec<(u32, Self)>) -> Self {
        Self::Routing { routes }
    }
}

impl Hook {
    async fn deploy_mock(
        codes: &Codes,
        gas: FieldElement,
        deployer: &StarknetAccount,
    ) -> eyre::Result<FieldElement> {
        let res = deploy_contract(codes.test_mock_hook, vec![], deployer).await;

        Ok(res.0)
    }

    async fn deploy_merkle(
        codes: &Codes,
        mailbox: FieldElement,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<FieldElement> {
        // deploy merkle hook

        Ok(FieldElement::ZERO)
    }

    async fn deploy_pausable(
        codes: &Codes,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<FieldElement> {
        todo!("not implemented")
    }

    async fn deploy_routing(
        code: u64,
        codes: &Codes,
        mailbox: FieldElement,
        routes: Vec<(u32, Self)>,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<FieldElement> {
        todo!("not implemented")
    }

    async fn deploy_aggregate(
        code: u64,
        codes: &Codes,
        mailbox: FieldElement,
        hooks: Vec<Self>,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> eyre::Result<FieldElement> {
        todo!("not implemented")
    }

    pub async fn deploy(
        self,
        codes: &Codes,
        mailbox: Option<FieldElement>,
        owner: &StarknetAccount,
        deployer: &StarknetAccount,
    ) -> Result<FieldElement> {
        match self {
            Hook::Mock { gas } => Self::deploy_mock(codes, gas, deployer).await,
            Hook::Igp(igp) => todo!("not implemented"),
            Hook::Merkle {} => {
                if let Some(mailbox) = mailbox {
                    Self::deploy_merkle(codes, mailbox, owner, deployer).await
                } else {
                    Err(eyre::eyre!("Mailbox is required for deploying Merkle hook"))
                }
            }
            Hook::Pausable {} => Self::deploy_pausable(codes, owner, deployer).await,
            Hook::Routing { routes } => todo!("not implemented"),
            Hook::RoutingCustom {
                routes,
                custom_hooks,
            } => {
                todo!("not implemented")
            }
            Hook::RoutingFallback {
                routes,
                fallback_hook,
            } => {
                todo!("not implemented")
            }
            Hook::Aggregate { hooks } => todo!("not implemented"),
        }
    }
}
