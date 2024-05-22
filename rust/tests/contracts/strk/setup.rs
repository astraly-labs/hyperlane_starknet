use std::collections::BTreeMap;

use katana_runner::KatanaRunner;
use starknet::core::types::FieldElement;

use crate::validator::TestValidators;

use super::{
    declare_all, deploy_core,
    hook::Hook,
    ism::prepare_routing_ism,
    types::{Codes, CoreDeployments},
    StarknetAccount,
};

const DEFAULT_GAS: u128 = 300_000;

pub struct Env {
    validators: BTreeMap<u32, TestValidators>,

    pub core: CoreDeployments,
    pub declared_classes: Codes,
    pub domain: u32,

    pub acc_owner: StarknetAccount,
    pub acc_tester: StarknetAccount,
    pub acc_deployer: StarknetAccount,
}

impl Env {
    pub fn get_validator_set(&self, domain: u32) -> eyre::Result<&TestValidators> {
        self.validators
            .get(&domain)
            .ok_or(eyre::eyre!("no validator set found"))
    }
}

pub async fn setup_env(domain: u32, validators: &[TestValidators]) -> eyre::Result<Env> {
    let runner = KatanaRunner::new().expect("Fail to set runner");

    let owner = runner.account(0);
    let deployer = runner.account(1);
    let tester = runner.account(2);

    let default_ism =
        prepare_routing_ism(validators.iter().map(|v| (v.domain, v.clone())).collect());

    let default_hook = Hook::mock(FieldElement::from(DEFAULT_GAS));

    let required_hook = Hook::Aggregate {
        hooks: vec![Hook::Merkle {}],
    };

    let declared_classes = declare_all(&deployer).await?;
    let core = deploy_core(
        &owner,
        &deployer,
        &declared_classes,
        domain,
        default_ism,
        default_hook,
        required_hook,
    )
    .await?;

    Ok(Env {
        validators: validators.iter().map(|v| (v.domain, v.clone())).collect(),

        core,
        declared_classes,
        domain,

        acc_owner: owner,
        acc_tester: tester,
        acc_deployer: deployer,
    })
}
