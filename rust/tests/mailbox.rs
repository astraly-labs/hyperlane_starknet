#[allow(dead_code)]
mod constants;
mod contracts;
mod validator;

use bytes::{buf, BufMut, BytesMut};
use cainome::cairo_serde::CairoSerde;
use contracts::{
    eth::mailbox::{DispatchFilter, DispatchIdFilter},
    strk::mailbox::{mailbox, Bytes, Dispatch as DispatchEvent, Message},
};
use ethers::{
    prelude::parse_log, providers::Middleware, signers::Signer, types::TransactionReceipt,
};
use starknet::{
    accounts::{Account, ConnectedAccount},
    core::{types::{Event, Felt, ReceiptBlock, TransactionReceiptWithBlockInfo}, utils::get_selector_from_name},
    macros::felt,
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
        sender: cainome::cairo_serde::U256::from_bytes_be(&found.data[0].to_bytes_be()),
        destination_domain: found.data[2].try_into().unwrap(),
        recipient_address: cainome::cairo_serde::U256::from_bytes_be(&found.data[3].to_bytes_be()),
        message: Message::cairo_deserialize(&found.data, 5).expect("Failed to deserialize message"),
    }
}

fn u128_vec_to_u8_vec(input: Vec<u128>) -> Vec<u8> {
    let mut output = Vec::with_capacity(input.len() * 16);
    for value in input {
        output.extend_from_slice(&value.to_be_bytes());
    }
    output
}

/// Convert a starknet message to eth message bytes
fn to_eth_message_bytes(starknet_message: Message) -> Vec<u8> {
    let mut buf =
        BytesMut::with_capacity(1 + 4 + 4 + 32 + 4 + 32 + starknet_message.body.size as usize);

    buf.put_u8(starknet_message.version);
    buf.put_u32(starknet_message.nonce);
    buf.put_u32(starknet_message.origin);
    buf.put_slice(&starknet_message.sender.to_bytes_be().as_slice());
    buf.put_u32(starknet_message.destination);
    buf.put_slice(starknet_message.recipient.to_bytes_be().as_slice());
    buf.put_slice(&u128_vec_to_u8_vec(starknet_message.body.data));

    println!("ETH message bytes: {:?}", buf.to_vec());

    buf.to_vec()
}

/// Convert a dispatch event to a starknet message
fn eth_dispatch_event_to_strk_message(event: DispatchFilter) -> Message {
    let mut buffer: [u8; 32] = [0; 32];
    buffer[..20].copy_from_slice(event.sender.as_bytes());
    let sender = cainome::cairo_serde::U256::from_bytes_be(&buffer);
    let recipient = cainome::cairo_serde::U256::from_bytes_be(&event.recipient);
    let destination = event.destination;

    let m = event.message;

    let version = m[0];
    let nonce = u32::from_be_bytes(m[1..5].try_into().unwrap());
    let origin = u32::from_be_bytes(m[5..9].try_into().unwrap());
    let body = m[77..].try_into().unwrap();

    println!("Starknet message: {:?}", m);

    Message {
        version,
        nonce,
        origin,
        sender,
        destination,
        recipient,
        body: to_strk_message_bytes(body),
    }
}

/// Convert a byte slice to a starknet message
/// We have to pad the bytes to 16 bytes chunks
/// see here for more info https://github.com/keep-starknet-strange/alexandria/blob/main/src/bytes/src/bytes.cairo#L16
fn to_strk_message_bytes(bytes: &[u8]) -> Bytes {
    // Calculate the required padding
    let padding = (16 - (bytes.len() % 16)) % 16;
    let total_len = bytes.len() + padding;

    // Create a new byte vector with the necessary padding
    let mut padded_bytes = Vec::with_capacity(total_len);
    padded_bytes.extend_from_slice(bytes);
    padded_bytes.extend(std::iter::repeat(0).take(padding));

    let mut result = Vec::with_capacity(total_len / 16);
    for chunk in padded_bytes.chunks_exact(16) {
        // Convert each 16-byte chunk into a u128
        let mut array = [0u8; 16];
        array.copy_from_slice(chunk);
        result.push(u128::from_be_bytes(array));
    }

    Bytes {
        size: bytes.len() as u32,
        data: result,
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
            &cainome::cairo_serde::U256::from_bytes_be(&receiver),
            &to_strk_message_bytes(msg_body),
            &cainome::cairo_serde::U256 { low: 0, high: 0 },
            &None,
            &None,
        )
        .send()
        .await?;
    let strk_provider: &AnyProvider = from.acc_owner.provider();
    let dispatch_receipt = strk_provider
        .get_transaction_receipt(dispatch_res.transaction_hash)
        .await?;

    let dispatch = match dispatch_receipt.block {
        ReceiptBlock::Pending => {
            // pending receipt
            match &dispatch_receipt.receipt {
                starknet::core::types::TransactionReceipt::Invoke(invoke_receipt) => {
                    parse_dispatch_from_res(&invoke_receipt.events)
                },
                _ => return Err(eyre::eyre!("Unexpected pending receipt type")),
            }
        },
        ReceiptBlock::Block { .. } => {
            // confirmed receipt
            match &dispatch_receipt.receipt {
                starknet::core::types::TransactionReceipt::Invoke(invoke_receipt) => {
                    parse_dispatch_from_res(&invoke_receipt.events)
                },
                _ => return Err(eyre::eyre!("Unexpected confirmed receipt type")),
            }
        },
    };

    // println!("\nDispatched: {:?}", dispatch);

    let process_tx = to
        .core
        .mailbox
        .process(vec![].into(), to_eth_message_bytes(dispatch.message).into());
    let process_tx_res = process_tx.send().await?.await?.unwrap();

    Ok(process_tx_res)
}

async fn send_msg_evm_to_strk<M, S>(
    from: &eth::Env<M, S>,
    to: &strk::Env,
) -> eyre::Result<TransactionReceiptWithBlockInfo>
where
    M: Middleware + 'static,
    S: Signer + 'static,
{
    // prepare message arguments
    // let sender = bech32_encode("osmo", from.acc_owner.address().as_bytes())?;
    let receiver = to.core.msg_receiver.to_bytes_be();
    let msg_body = b"hello world";

    let version = from.core.mailbox.version().call().await?;
    println!("version: {:?}", version);

    // dispatch
    let dispatch_tx_call = from
        .core
        .mailbox
        .dispatch_0(DOMAIN_STRK, receiver, msg_body.into());
    let dispatch_res = dispatch_tx_call.send().await?.await?.unwrap();
    let dispatch: DispatchFilter = parse_log(dispatch_res.logs[0].clone())?;
    let dispatch_id: DispatchIdFilter = parse_log(dispatch_res.logs[1].clone())?;

    // dispatch
    let mailbox_contract = mailbox::new(to.core.mailbox, &to.acc_tester);
    // println!(
    //     "message: {:?}",
    //     eth_dispatch_event_to_strk_message(dispatch.clone())
    // );
    let process_res = mailbox_contract
        .process(
            &Bytes {
                size: 0,
                data: vec![],
            },
            &eth_dispatch_event_to_strk_message(dispatch),
        )
        .send()
        .await?;

    let strk_provider: &AnyProvider = to.acc_owner.provider();
    let process_receipt = strk_provider
        .get_transaction_receipt(process_res.transaction_hash)
        .await?;

    Ok(process_receipt)
}

#[tokio::test]
async fn test_mailbox_strk_to_evm() -> eyre::Result<()> {
    // init starknet env
    let strk = strk::setup_env(DOMAIN_STRK, &[TestValidators::new(DOMAIN_EVM, 5, 3)]).await?;

    // init eth env
    let anvil = eth::setup_env(DOMAIN_EVM).await?;
    let _ = send_msg_strk_to_evm(&strk, &anvil).await?;

    Ok(())
}

#[tokio::test]
async fn test_mailbox_evm_to_strk() -> eyre::Result<()> {
    // init starknet env
    let strk = strk::setup_env(DOMAIN_STRK, &[TestValidators::new(DOMAIN_EVM, 5, 3)]).await?;

    // init eth env
    let anvil = eth::setup_env(DOMAIN_EVM).await?;

    let _ = send_msg_evm_to_strk(&anvil, &strk).await?;

    Ok(())
}
