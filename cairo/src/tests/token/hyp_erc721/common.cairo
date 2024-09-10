use alexandria_bytes::{Bytes, BytesTrait};
use hyperlane_starknet::contracts::client::gas_router_component::{
    GasRouterComponent::GasRouterConfig, IGasRouterDispatcher, IGasRouterDispatcherTrait
};
use hyperlane_starknet::contracts::client::router_component::{
    IRouterDispatcher, IRouterDispatcherTrait
};
use hyperlane_starknet::contracts::mocks::{
    test_post_dispatch_hook::{
        ITestPostDispatchHookDispatcher, ITestPostDispatchHookDispatcherTrait
    },
    mock_mailbox::{IMockMailboxDispatcher, IMockMailboxDispatcherTrait},
    // test_erc721::{ITestERC721Dispatcher, ITestERC721DispatcherTrait},
    test_interchain_gas_payment::{
        ITestInterchainGasPaymentDispatcher, ITestInterchainGasPaymentDispatcherTrait
    },
};
use hyperlane_starknet::contracts::token::components::hyp_erc721_collateral_component::{
    IHypErc721CollateralDispatcher, IHypErc721CollateralDispatcherTrait
};
use hyperlane_starknet::contracts::token::components::hyp_erc721_component::{
    IHypErc721Dispatcher, IHypErc721DispatcherTrait
};
use hyperlane_starknet::contracts::token::components::token_router::{
    ITokenRouterDispatcher, ITokenRouterDispatcherTrait
};
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait, IMailboxClientDispatcher, IMailboxClientDispatcherTrait
};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn,
    start_prank, stop_prank, EventFetcher, event_name_hash
};
use starknet::ContractAddress;

const ZERO_SUPPLY: u256 = 0;
fn ZERO_ADDRESS() -> ContractAddress {
    starknet::contract_address_const::<'0x0'>()
}
fn EMPTY_STRING() -> ByteArray {
    ""
}

const INITIAL_SUPPLY: u32 = 10;
fn NAME() -> ByteArray {
    "Hyperlane Hedgehogs"
}
fn SYMBOL() -> ByteArray {
    "HHH"
}

fn ALICE() -> ContractAddress {
    starknet::contract_address_const::<'0x1'>()
}
fn BOB() -> ContractAddress {
    starknet::contract_address_const::<'0x2'>()
}
fn PROXY_ADMIN() -> ContractAddress {
    starknet::contract_address_const::<'0x37'>()
}
const ORIGIN: u32 = 11;
const DESTINATION: u32 = 22;
const TRANSFER_ID: u256 = 0;
fn URI() -> ByteArray {
    "http://bit.ly/3reJLpx"
}

#[derive(Copy, Drop)]
struct Setup {
    primary_token: IERC721Dispatcher,
    remote_primary_token: IERC721Dispatcher,
    noop_hook: ITestPostDispatchHookDispatcher,
    local_mailbox: IMockMailboxDispatcher,
    remote_mailbox: IMockMailboxDispatcher,
    remote_token: IHypErc721CollateralDispatcher,
    local_token: IHypErc721Dispatcher,
}

fn setup() -> Setup {
    let contract = declare("TestERC721").unwrap();
    let (primary_token, _) = contract.deploy(@array![(INITIAL_SUPPLY * 2).into()]).unwrap();
    let primary_token = IERC721Dispatcher { contract_address: primary_token };

    let (remote_primary_token, _) = contract.deploy(@array![(INITIAL_SUPPLY * 2).into()]).unwrap();
    let remote_primary_token = IERC721Dispatcher { contract_address: remote_primary_token };

    let contract = declare("TestPostDispatchHook").unwrap();
    let (noop_hook, _) = contract.deploy(@array![]).unwrap();
    let noop_hook = ITestPostDispatchHookDispatcher { contract_address: noop_hook };

    let contract = declare("TestISM").unwrap();
    let (default_ism, _) = contract.deploy(@array![]).unwrap();

    let contract = declare("Ether").unwrap();
    let mut calldata: Array<felt252> = array![];
    starknet::get_contract_address().serialize(ref calldata);
    let (eth_address, _) = contract.deploy(@calldata).unwrap();
    println!("ETH: {:?}", eth_address);
    //let eth = MockEthDispatcher { contract_address: eth_address };

    let contract = declare("MockMailbox").unwrap();
    let (local_mailbox, _) = contract
        .deploy(
            @array![
                ORIGIN.into(),
                default_ism.into(),
                noop_hook.contract_address.into(),
                eth_address.into()
            ]
        )
        .unwrap();
    let local_mailbox = IMockMailboxDispatcher { contract_address: local_mailbox };

    let (remote_mailbox, _) = contract
        .deploy(
            @array![
                DESTINATION.into(),
                default_ism.into(),
                noop_hook.contract_address.into(),
                eth_address.into()
            ]
        )
        .unwrap();
    let remote_mailbox = IMockMailboxDispatcher { contract_address: remote_mailbox };

    local_mailbox.set_default_hook(noop_hook.contract_address);
    local_mailbox.set_required_hook(noop_hook.contract_address);

    let contract = declare("HypErc721Collateral").unwrap();
    let (remote_token, _) = contract
        .deploy(
            @array![
                remote_primary_token.contract_address.into(),
                remote_mailbox.contract_address.into(),
                noop_hook.contract_address.into(),
                default_ism.into(),
                starknet::get_contract_address().into()
            ]
        )
        .unwrap();
    let remote_token = IHypErc721CollateralDispatcher { contract_address: remote_token };

    let contract = declare("HypErc721").unwrap();
    let mut calldata: Array<felt252> = array![];
    local_mailbox.contract_address.serialize(ref calldata);
    EMPTY_STRING().serialize(ref calldata);
    EMPTY_STRING().serialize(ref calldata);
    ZERO_SUPPLY.serialize(ref calldata);
    calldata.append(noop_hook.contract_address.into());
    calldata.append(default_ism.into());
    calldata.append(starknet::get_contract_address().into());
    let (local_token, _) = contract.deploy(@calldata).unwrap();
    let local_token = IHypErc721Dispatcher { contract_address: local_token };

    Setup {
        primary_token,
        remote_primary_token,
        noop_hook,
        local_mailbox,
        remote_mailbox,
        remote_token,
        local_token
    }
}

pub fn deploy_remote_token(
    setup: @Setup, is_collateral: bool
) -> (ContractAddress, ContractAddress) {
    if is_collateral {
        let contract = declare("HypErc721Collateral").unwrap();
        let (implementation, _) = contract
            .deploy(
                @array![
                    (*setup).remote_primary_token.contract_address.into(),
                    (*setup).remote_mailbox.contract_address.into(),
                ]
            )
            .unwrap();
        let implementation = IHypErc721CollateralDispatcher { contract_address: implementation };

        let (remote_token, _) = contract
            .deploy(@array![ZERO_ADDRESS().into(), ZERO_ADDRESS().into()])
            .unwrap();
        let remote_token = IHypErc721CollateralDispatcher { contract_address: remote_token };

        (*setup)
            .remote_primary_token
            .transfer_from(starknet::get_contract_address(), remote_token.contract_address, 0);

        (implementation.contract_address, remote_token.contract_address)
    } else {
        let contract = declare("HypErc721").unwrap();
        let mut calldata: Array<felt252> = array![];
        (*setup).remote_mailbox.contract_address.serialize(ref calldata);
        EMPTY_STRING().serialize(ref calldata);
        EMPTY_STRING().serialize(ref calldata);
        ZERO_SUPPLY.serialize(ref calldata);
        let (implementation, _) = contract.deploy(@calldata).unwrap();
        let implementation = IHypErc721Dispatcher { contract_address: implementation };

        let mut calldata: Array<felt252> = array![];
        ZERO_ADDRESS().serialize(ref calldata);
        NAME().serialize(ref calldata);
        SYMBOL().serialize(ref calldata);
        ZERO_SUPPLY.serialize(ref calldata);
        let (remote_token, _) = contract.deploy(@calldata).unwrap();
        let remote_token = IHypErc721Dispatcher { contract_address: remote_token };

        let token_router = IRouterDispatcher { contract_address: remote_token.contract_address };
        let local_token_address: felt252 = (*setup).local_token.contract_address.into();
        token_router.enroll_remote_router(ORIGIN, local_token_address.into());
        (implementation.contract_address, remote_token.contract_address)
    }
}

pub fn process_transfer(setup: @Setup, recipient: ContractAddress, token_id: u256) {
    start_prank(
        CheatTarget::One((*setup).remote_token.contract_address),
        (*setup).remote_mailbox.contract_address
    );
    let message_recipient = IMessageRecipientDispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    let mut message = BytesTrait::new_empty();
    message.append_address(recipient);
    message.append_u256(token_id);
    let local_token_address: felt252 = (*setup).local_token.contract_address.into();
    message_recipient.handle(ORIGIN, local_token_address.into(), message);
}

pub fn perform_remote_transfer(setup: @Setup, msg_value: u256, token_id: u256) {
    let token_router = ITokenRouterDispatcher {
        contract_address: (*setup).local_token.contract_address
    };
    let alice_address: felt252 = ALICE().into();
    token_router
        .transfer_remote(
            DESTINATION, alice_address.into(), token_id, msg_value, Option::None, Option::None
        );
}

#[test]
fn test_erc721_setup() {
    let _ = setup();
}
