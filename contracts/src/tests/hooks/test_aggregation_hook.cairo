use alexandria_bytes::{Bytes, BytesTrait};
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
use hyperlane_starknet::contracts::mocks::hook::{IMockHookDispatcher, IMockHookDispatcherTrait};
use hyperlane_starknet::interfaces::{
    Types, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait,
};
use hyperlane_starknet::tests::setup::{setup_mock_token, setup_aggregation_hook, OWNER};
use snforge_std::{declare, ContractClassTrait, start_prank, CheatTarget, stop_prank};
use starknet::{ContractAddress};

fn _build_metadata() -> Bytes {
    let mut metadata = BytesTrait::new_empty();
    let variant = 1;
    metadata.append_u16(variant);
    metadata
}

fn _build_hook_list(quotes: @Array<u256>) -> Span<ContractAddress> {
    let mut hooks = array![];
    let mock_hook = declare("hook").unwrap();

    let mut i = 0;
    loop {
        if i >= quotes.len() {
            break;
        }

        let (contract_address, _) = mock_hook.deploy(@array![]).unwrap();
        IMockHookDispatcher { contract_address }.set_quote_dispatch(*quotes.at(i));

        hooks.append(contract_address);

        i += 1;
    };

    hooks.span()
}

fn _setup_eth_balance(token_dispatcher: IERC20Dispatcher, recipient: ContractAddress, amount: u256) {
    let ownable = IOwnableDispatcher { contract_address: token_dispatcher.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    token_dispatcher.transfer(recipient, amount);
    assert_eq!(token_dispatcher.balance_of(recipient), amount);
    stop_prank(CheatTarget::One(ownable.contract_address));
}

#[test]
fn test_hook_type() {
    setup_mock_token();
    let hooks = _build_hook_list(@array![100_u256, 200_u256, 300_u256]);
    let post_dispatch_hook = setup_aggregation_hook(@hooks);

    assert_eq!(post_dispatch_hook.hook_type(), Types::AGGREGATION(()));
}

#[test]
fn test_aggregate_quote_dispatch() {
    // arrange
    setup_mock_token();
    let hooks = _build_hook_list(@array![100_u256, 200_u256, 300_u256]);
    let post_dispatch_hook = setup_aggregation_hook(@hooks);

    let expected_quote = 600_u256;

    // act
    let quote = post_dispatch_hook.quote_dispatch(_build_metadata(), MessageTrait::default());

    // assert
    assert_eq!(quote, expected_quote);

    let mut i = 0;
    loop {
        if i >= hooks.len() {
            break;
        }

        let contract_address = *hooks.at(i);
        assert_eq!(IMockHookDispatcher { contract_address }.get_quote_dispatch_calls(), 1);

        i += 1;
    }
}

#[test]
fn test_aggregate_post_dispatch() {
    // arrange
    let token_dispatcher = setup_mock_token();

    let hooks = _build_hook_list(@array![100_u256, 200_u256, 300_u256]);
    let fee_amount = 600_u256;
    let post_dispatch_hook = setup_aggregation_hook(@hooks);

    _setup_eth_balance(token_dispatcher, post_dispatch_hook.contract_address, fee_amount);

    // act
    post_dispatch_hook.post_dispatch(_build_metadata(), MessageTrait::default(), fee_amount);

    // assert
    let mut i = 0;
    loop {
        if i >= hooks.len() {
            break;
        }

        let contract_address = *hooks.at(i);
        assert_eq!(IMockHookDispatcher { contract_address }.get_post_dispatch_calls(), 1);

        i += 1;
    }
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_aggregate_post_dispatch_insufficient_balance() {
    // arrange
    setup_mock_token();

    let hooks = _build_hook_list(@array![100_u256, 200_u256, 300_u256]);
    let fee_amount = 600_u256;
    let post_dispatch_hook = setup_aggregation_hook(@hooks);

    // act
    post_dispatch_hook.post_dispatch(_build_metadata(), MessageTrait::default(), fee_amount);
}

#[test]
#[should_panic(expected: ('Insufficient funds',))]
fn test_aggregate_post_dispatch_insufficient_funds() {
    // arrange
    let token_dispatcher = setup_mock_token();

    let hooks = _build_hook_list(@array![100_u256, 200_u256, 300_u256]);
    let fee_amount = 599_u256;
    let post_dispatch_hook = setup_aggregation_hook(@hooks);

    _setup_eth_balance(token_dispatcher, post_dispatch_hook.contract_address, fee_amount);

    // act
    post_dispatch_hook.post_dispatch(_build_metadata(), MessageTrait::default(), fee_amount);
}