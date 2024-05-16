use starknet::accounts::{Account, ConnectedAccount};

use super::{
    bind::mailbox::mailbox,
    deploy_contract,
    hook::Hook,
    ism::Ism,
    types::{Codes, CoreDeployments},
    StarknetAccount,
};

pub async fn deploy_core(
    owner: &StarknetAccount,
    deployer: &StarknetAccount,
    codes: &Codes,
    domain: u32,
    default_ism: Ism,
    default_hook: Hook,
    required_hook: Hook,
) -> eyre::Result<CoreDeployments> {
    // deploy mailbox
    let (mailbox, _) = deploy_contract(
        codes.mailbox,
        vec![domain.into(), owner.address()],
        deployer.get_nonce().await?,
        deployer,
    )
    .await;

    // set default ism, hook, igp
    let default_ism = default_ism.deploy(codes, owner, deployer).await?;
    let default_hook = default_hook
        .deploy(codes, mailbox.clone(), owner, deployer)
        .await?;
    let required_hook = required_hook
        .deploy(codes, mailbox.clone(), owner, deployer)
        .await?;

    let mailbox_contract = mailbox::new(mailbox, owner);
    mailbox_contract
        .set_default_ism(&default_ism.into())
        .send()
        .await?;
    mailbox_contract
        .set_default_hook(&default_hook.into())
        .send()
        .await?;
    mailbox_contract
        .set_required_hook(&required_hook.into())
        .send()
        .await?;

    // deploy test message receiver
    let (msg_receiver, _) = deploy_contract(
        codes.test_mock_msg_receiver,
        vec![mailbox.clone()],
        deployer.get_nonce().await?,
        deployer,
    )
    .await;

    Ok(CoreDeployments {
        mailbox,
        default_ism,
        default_hook,
        required_hook,
        msg_receiver,
    })
}
