use super::{
    hook::Hook,
    ism::Ism,
    types::{Codes, CoreDeployments},
    StarknetAccount,
};

pub fn deploy_core(
    owner: &StarknetAccount,
    deployer: &StarknetAccount,
    codes: &Codes,
    domain: u32,
    default_ism: Ism,
    default_hook: Hook,
    required_hook: Hook,
) -> eyre::Result<CoreDeployments> {
    // deploy mailbox
    Ok(CoreDeployments::default())
}
