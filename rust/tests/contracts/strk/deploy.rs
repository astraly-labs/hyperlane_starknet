use starknet::{accounts::Account, core::types::FieldElement};

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
    println!("\n==> Deploying Mailbox");
    let (mailbox, _) = deploy_contract(
        codes.mailbox,
        vec![domain.into(), owner.address()],
        deployer,
    )
    .await;
    println!("Deployed Contract Address {:x?}", mailbox);

    // set default ism, hook, igp
    println!("\n==> Deploying default ism, hook, igp");
    let default_ism = default_ism.deploy(codes, owner, deployer).await?;
    let default_hook = default_hook
        .deploy(codes, mailbox.clone(), owner, deployer)
        .await?;
    // let required_hook = required_hook
    //     .deploy(codes, mailbox.clone(), owner, deployer)
    //     .await?;
    println!("Default ISM: {:x?}", default_ism);
    println!("Default Hook: {:x?}", default_hook);
    // println!("Required Hook: {:x?}", required_hook);

    let mailbox_contract = mailbox::new(mailbox, owner);

    mailbox_contract
        .set_default_ism(&default_ism.into())
        .send()
        .await?;
    mailbox_contract
        .set_default_hook(&default_hook.into())
        .send()
        .await?;
    // mailbox_contract
    //     .set_required_hook(&required_hook.into())
    //     .send()
    //     .await?;

    // deploy test message receiver
    println!("\n==> Deploying test message receiver");
    let (msg_receiver, _) = deploy_contract(codes.test_mock_msg_receiver, vec![], deployer).await;
    println!("Deployed Contract Address {:x?}", msg_receiver);

    Ok(CoreDeployments {
        mailbox,
        default_ism,
        default_hook,
        required_hook: FieldElement::ZERO,
        msg_receiver,
    })
}
