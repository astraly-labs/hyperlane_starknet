use std::{collections::BTreeMap, path::PathBuf};

use starknet::core::types::FieldElement;

use crate::validator::TestValidators;

use super::{
    deploy_core, get_dev_account,
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

pub fn setup_env(
    artifacts: Option<impl Into<PathBuf>>,
    hrp: &str,
    domain: u32,
    validators: &[TestValidators],
) -> eyre::Result<Env> {
    let owner = get_dev_account(0);
    let deployer = get_dev_account(1);
    let tester = get_dev_account(2);

    let default_ism =
        prepare_routing_ism(validators.iter().map(|v| (v.domain, v.clone())).collect());

    let default_hook = Hook::mock(FieldElement::from(DEFAULT_GAS));

    let required_hook = Hook::Aggregate {
        hooks: vec![Hook::Merkle {}],
    };

    let declared_classes = declare_all(&deployer, artifacts)?;
    let core = deploy_core(
        &owner,
        &deployer,
        &declared_classes,
        domain,
        default_ism,
        default_hook,
        required_hook,
    )?;

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
