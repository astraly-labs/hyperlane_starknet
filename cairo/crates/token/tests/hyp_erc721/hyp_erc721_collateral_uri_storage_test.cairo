use alexandria_bytes::Bytes;
use contracts::client::router_component::{IRouterDispatcher, IRouterDispatcherTrait};
use mocks::test_erc721::{ITestERC721Dispatcher, ITestERC721DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, EventSpy,
    EventSpyAssertionsTrait, cheat_caller_address, declare, spy_events,
};
use starknet::ContractAddress;
use super::common::{
    ALICE, BOB, DESTINATION, IHypErc721TestDispatcher, IHypErc721TestDispatcherTrait,
    INITIAL_SUPPLY, NAME, SYMBOL, Setup, TRANSFER_ID, URI, ZERO_ADDRESS, deploy_remote_token,
    perform_remote_transfer, process_transfer, setup,
};
use token::components::token_router::{ITokenRouterDispatcher, ITokenRouterDispatcherTrait};

fn setup_erc721_collateral_uri_storage() -> Setup {
    let mut setup = setup();

    let contract = declare("HypERC721URICollateral").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    setup.local_primary_token.contract_address.serialize(ref calldata);
    setup.local_mailbox.contract_address.serialize(ref calldata);
    setup.noop_hook.contract_address.serialize(ref calldata);
    starknet::get_contract_address().serialize(ref calldata);
    let (hyp_erc721_uri_collateral, _) = contract.deploy(@calldata).unwrap();
    let hyp_erc721_uri_collateral = IHypErc721TestDispatcher {
        contract_address: hyp_erc721_uri_collateral,
    };

    let remote_token_address: felt252 = setup.remote_token.contract_address.into();
    hyp_erc721_uri_collateral.enroll_remote_router(DESTINATION, remote_token_address.into());

    setup
        .local_primary_token
        .transfer_from(
            starknet::get_contract_address(),
            hyp_erc721_uri_collateral.contract_address,
            INITIAL_SUPPLY + 1,
        );

    setup.local_token = hyp_erc721_uri_collateral;

    setup
}

#[test]
fn test_erc721_collateral_uri_storage_remote_transfer_revert_burned() {
    let setup = setup_erc721_collateral_uri_storage();

    let setup = deploy_remote_token(setup, false);
    setup.local_primary_token.approve(setup.local_token.contract_address, 0);
    let bob_address: felt252 = setup.bob.into();
    setup
        .local_token
        .transfer_remote(
            DESTINATION, bob_address.into(), TRANSFER_ID, 2500, Option::None, Option::None,
        );
    process_transfer(@setup, setup.bob, 0);
    assert_eq!(setup.remote_token.balance_of(setup.bob), 1);
    assert_eq!(
        setup.local_token.balance_of(starknet::get_contract_address()), INITIAL_SUPPLY * 2 - 2,
    );
}

