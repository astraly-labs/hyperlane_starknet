#[allow(dead_code)]
mod constants;
mod contracts;
mod event;
mod validator;

use contracts::strk::mailbox::{mailbox, Bytes};
use ethers::{
    prelude::parse_log, providers::Middleware, signers::Signer, types::TransactionReceipt,
};
use event::parse_dispatch_from_res;
use starknet::{
    accounts::{Account, ConnectedAccount},
    core::types::{FieldElement, MaybePendingTransactionReceipt},
    providers::{AnyProvider, Provider},
};

use crate::{
    constants::{DOMAIN_EVM, DOMAIN_STRK},
    contracts::{eth, strk},
    validator::TestValidators,
};

async fn send_msg_strk_to_evm<M, S>(
    from: &strk::Env,
    to: &eth::Env<M, S>,
) -> eyre::Result<TransactionReceipt>
where
    M: Middleware + 'static,
    S: Signer + 'static,
{
    let mut receiver = [0u8; 32];
    receiver[12..].copy_from_slice(&to.core.msg_receiver.address().0);
    let _sender = from.acc_tester.address();
    let msg_body = b"hello world";

    // dispatch
    let mailbox_contract = mailbox::new(from.core.mailbox, &from.acc_tester);
    let dispatch_res = mailbox_contract
        .dispatch(
            &DOMAIN_EVM,
            &cainome::cairo_serde::ContractAddress(FieldElement::from_bytes_be(&receiver).unwrap()),
            &Bytes {
                size: msg_body.len() as u32,
                data: msg_body.iter().map(|b| *b as u128).collect(),
            },
            &None,
            &None,
        )
        .send()
        .await?;
    let strk_provider: &AnyProvider = from.acc_owner.provider();
    let dispatch_receipt = strk_provider
        .get_transaction_receipt(dispatch_res.transaction_hash)
        .await?;

    let dispatch = match dispatch_receipt {
        MaybePendingTransactionReceipt::PendingReceipt(_) => {
            return Err(eyre::eyre!("Transaction is pending"))
        }
        MaybePendingTransactionReceipt::Receipt(receipt) => match receipt {
            starknet::core::types::TransactionReceipt::Invoke(receipt) => {
                parse_dispatch_from_res(&receipt.events)
            }
            _ => return Err(eyre::eyre!("Unexpected receipt type, check the hash")),
        },
    };

    let process_tx = to.core.mailbox.process(
        vec![].into(),
        dispatch.message.to_bytes_be().as_slice().to_vec().into(),
    );
    let process_tx_res = process_tx.send().await?.await?.unwrap();

    Ok(process_tx_res)
}

#[tokio::test]
async fn test_mailbox_cw_to_evm() -> eyre::Result<()> {
    // init starknet env
    let strk = strk::setup_env(DOMAIN_STRK, &[TestValidators::new(DOMAIN_EVM, 5, 3)]).await?;

    // init eth env
    let anvil = eth::setup_env(DOMAIN_EVM).await?;

    let _ = send_msg_strk_to_evm(&strk, &anvil).await?;

    Ok(())
}
