use super::{hook::Hook, types::Codes, StarknetAccount};

pub fn deploy_core(
    owner: StarknetAccount,
    deployer: StarknetAccount,
    codes: &Codes,
    domain: u32,
    default_ism: String,
    default_hook: Hook,
    required_hook: Hook,
) {
    // deploy mailbox
}
