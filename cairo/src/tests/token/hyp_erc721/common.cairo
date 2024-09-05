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
    hyp_erc721_collateral: IHypErc721CollateralDispatcher,
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

    let contract = declare("MockMailbox").unwrap();
    let (local_mailbox, _) = contract
        .deploy(@array![ORIGIN.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let local_mailbox = IMockMailboxDispatcher { contract_address: local_mailbox };

    let (remote_mailbox, _) = contract
        .deploy(@array![DESTINATION.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let remote_mailbox = IMockMailboxDispatcher { contract_address: remote_mailbox };

    local_mailbox.set_default_hook(noop_hook.contract_address);
    local_mailbox.set_required_hook(noop_hook.contract_address);

    let contract = declare("HypErc721Collateral").unwrap();
    let (hyp_erc721_collateral, _) = contract
        .deploy(
            @array![
                remote_primary_token.contract_address.into(), remote_mailbox.contract_address.into(),
            ]
        )
        .unwrap();
    let hyp_erc721_collateral = IHypErc721CollateralDispatcher {
        contract_address: hyp_erc721_collateral
    };

    Setup {
        primary_token,
        remote_primary_token,
        noop_hook,
        local_mailbox,
        remote_mailbox,
        hyp_erc721_collateral,
    }
}

#[test]
fn test_erc721_setup() {
    let _ = setup();
}
