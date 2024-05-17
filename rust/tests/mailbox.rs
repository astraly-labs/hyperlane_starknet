#[allow(dead_code)]
mod constants;
mod contracts;
mod validator;

use contracts::strk::mailbox::{mailbox, Bytes, Dispatch as DispatchEvent};
use ethers::{
    prelude::parse_log, providers::Middleware, signers::Signer, types::TransactionReceipt,
};
use starknet::{
    accounts::{Account, ConnectedAccount},
    core::types::{Event, FieldElement, MaybePendingTransactionReceipt},
    core::utils::get_selector_from_name,
    providers::{AnyProvider, Provider},
};

use crate::{
    constants::{DOMAIN_EVM, DOMAIN_STRK},
    contracts::{eth, strk},
    validator::TestValidators,
};

/// Parse the dispatch event from the receipt events
pub fn parse_dispatch_from_res(events: &[Event]) -> DispatchEvent {
    let key = get_selector_from_name("Dispatch").unwrap(); // safe to unwrap
    let found = events.iter().find(|v| v.keys.contains(&key)).unwrap();

    DispatchEvent {
        sender: cainome::cairo_serde::ContractAddress(found.data[0]),
        destination_domain: found.data[1].try_into().unwrap(),
        recipient_address: cainome::cairo_serde::ContractAddress(found.data[2]),
        message: (found.data[3], found.data[4]).try_into().unwrap(),
    }
}

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
        MaybePendingTransactionReceipt::PendingReceipt(pending_receipt) => match pending_receipt {
            starknet::core::types::PendingTransactionReceipt::Invoke(receipt) => {
                parse_dispatch_from_res(&receipt.events)
            }
            _ => return Err(eyre::eyre!("Unexpected receipt type, check the hash")),
        },
        MaybePendingTransactionReceipt::Receipt(receipt) => match receipt {
            starknet::core::types::TransactionReceipt::Invoke(receipt) => {
                parse_dispatch_from_res(&receipt.events)
            }
            _ => return Err(eyre::eyre!("Unexpected receipt type, check the hash")),
        },
    };

    println!("\nDispatched: {:?}", dispatch);

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
