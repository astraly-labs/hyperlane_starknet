use std::sync::Arc;

use ethers::{prelude::SignerMiddleware, providers::Middleware, signers::Signer};

use super::{mailbox, test_merkle_tree_hook, test_mock_ism, test_mock_msg_receiver, types};

pub async fn deploy<'a, M: Middleware + 'static, S: Signer + 'static>(
    signer: Arc<SignerMiddleware<M, S>>,
    evm_domain: u32,
) -> eyre::Result<types::Deployments<M, S>> {
    let ism_multisig_contract = test_mock_ism::TestMultisigIsm::deploy(signer.clone(), ())?
        .send()
        .await?;

    let msg_receiver_contract = test_mock_msg_receiver::TestRecipient::deploy(signer.clone(), ())?
        .send()
        .await?;

    let mailbox_contract = mailbox::Mailbox::deploy(signer.clone(), evm_domain)?
        .send()
        .await?;

    let merkle_tree_hook_contract = test_merkle_tree_hook::TestMerkleTreeHook::deploy(
        signer.clone(),
        mailbox_contract.address(),
    )?
    .send()
    .await?;

    let _ = mailbox_contract
        .initialize(
            signer.address(),
            ism_multisig_contract.address(),
            merkle_tree_hook_contract.address(),
            merkle_tree_hook_contract.address(),
        )
        .send()
        .await?
        .await?;

    let deployments = types::Deployments {
        mailbox: mailbox_contract,
        ism: ism_multisig_contract,
        msg_receiver: msg_receiver_contract,
        hook: merkle_tree_hook_contract,
    };

    Ok(deployments)
}
