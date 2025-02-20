use alexandria_bytes::{Bytes, BytesTrait};
use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::VARIANT;
use core::integer::BoundedInt;
use mocks::test_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait};
use mocks::test_interchain_gas_payment::ITestInterchainGasPaymentDispatcherTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn,
    start_prank, stop_prank, EventFetcher, event_name_hash
};
use starknet::ContractAddress;
use super::common::{
    setup, TOTAL_SUPPLY, DECIMALS, ORIGIN, TRANSFER_AMT, DESTINATION, OWNER,
    perform_remote_transfer_with_emit, perform_remote_transfer_and_gas, ALICE, BOB, E18,
    IHypERC20TestDispatcher, IHypERC20TestDispatcherTrait, enroll_remote_router,
    enroll_local_router, perform_remote_transfer, set_custom_gas_config, REQUIRED_VALUE, GAS_LIMIT,
    Setup, handle_local_transfer, test_transfer_with_hook_specified
};

fn fiat_token_setup() -> Setup {
    let mut setup = setup();

    let local_token = declare("HypFiatToken").unwrap();

    let mut calldata: Array<felt252> = array![];
    setup.primary_token.contract_address.serialize(ref calldata);
    setup.local_mailbox.contract_address.serialize(ref calldata);
    setup.noop_hook.contract_address.serialize(ref calldata);
    setup.igp.contract_address.serialize(ref calldata);
    starknet::get_contract_address().serialize(ref calldata);

    let (fiat_token, _) = local_token.deploy(@calldata).unwrap();
    let fiat_token = IHypERC20TestDispatcher { contract_address: fiat_token };

    start_prank(CheatTarget::One(setup.eth_token.contract_address), ALICE());
    ITestERC20Dispatcher { contract_address: setup.eth_token.contract_address }
        .approve(fiat_token.contract_address, BoundedInt::max());
    stop_prank(CheatTarget::One(setup.eth_token.contract_address));

    let remote_token_address: felt252 = setup.remote_token.contract_address.into();
    fiat_token.enroll_remote_router(DESTINATION, remote_token_address.into());

    setup.primary_token.transfer(setup.local_token.contract_address, 1000 * E18);
    setup.primary_token.transfer(ALICE(), 1000 * E18);

    setup.local_token = fiat_token;
    enroll_remote_router(@setup);

    setup
}

#[test]
fn test_fiat_token_remote_transfer() {
    let setup = fiat_token_setup();

    let balance_before = setup.local_token.balance_of(ALICE());

    start_prank(CheatTarget::One((setup).primary_token.contract_address), ALICE());
    setup.primary_token.approve(setup.local_token.contract_address, TRANSFER_AMT);
    stop_prank(CheatTarget::One(setup.primary_token.contract_address));

    perform_remote_transfer_and_gas(@setup, REQUIRED_VALUE, TRANSFER_AMT, 0);
    let balance_after = setup.local_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
}

#[test]
fn test_fiat_token_remote_transfer_with_custom_gas_config() {
    let setup = fiat_token_setup();

    set_custom_gas_config(@setup);

    let gas_price = setup.igp.gas_price();

    start_prank(CheatTarget::One((setup).primary_token.contract_address), ALICE());
    setup.primary_token.approve(setup.local_token.contract_address, TRANSFER_AMT);
    stop_prank(CheatTarget::One(setup.primary_token.contract_address));

    let balance_before = setup.local_token.balance_of(ALICE());
    perform_remote_transfer_and_gas(@setup, REQUIRED_VALUE, TRANSFER_AMT, GAS_LIMIT * gas_price);
    let balance_after = setup.local_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
    let eth_dispatcher = IERC20Dispatcher { contract_address: setup.eth_token.contract_address };
    assert_eq!(
        eth_dispatcher.balance_of(setup.igp.contract_address),
        GAS_LIMIT * gas_price,
        "Gas fee didnt transferred"
    );
}

#[test]
fn test_fiat_token_remote_transfer_with_hook_specified(mut fee: u256, metadata: u256) {
    let fee = fee % (TRANSFER_AMT / 10);
    let mut metadata_bytes = BytesTrait::new_empty();
    metadata_bytes.append_u16(VARIANT);
    metadata_bytes.append_u256(metadata);
    let setup = fiat_token_setup();

    start_prank(CheatTarget::One((setup).primary_token.contract_address), ALICE());
    setup.primary_token.approve(setup.local_token.contract_address, TRANSFER_AMT);
    stop_prank(CheatTarget::One(setup.primary_token.contract_address));

    let balance_before = setup.local_token.balance_of(ALICE());
    test_transfer_with_hook_specified(@setup, fee, metadata_bytes);
    let balance_after = setup.local_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
}

#[test]
fn test_fiat_token_handle() {
    let setup = fiat_token_setup();
    handle_local_transfer(@setup, TRANSFER_AMT);
}
