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
    test_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait},
    test_interchain_gas_payment::{
        ITestInterchainGasPaymentDispatcher, ITestInterchainGasPaymentDispatcherTrait
    },
};

use hyperlane_starknet::contracts::token::components::hyp_erc20_component::{
    IHypErc20Dispatcher, IHypErc20DispatcherTrait
};
use hyperlane_starknet::contracts::token::components::token_router::{
    ITokenRouterDispatcher, ITokenRouterDispatcherTrait
};
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait, IMailboxClientDispatcher, IMailboxClientDispatcherTrait
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn,
    start_prank, stop_prank, EventFetcher, event_name_hash
};
use starknet::ContractAddress;

const E18: u256 = 1_000_000_000_000_000_000;
const ORIGIN: u32 = 11;
const DESTINATION: u32 = 12;
const DECIMALS: u8 = 18;
const TOTAL_SUPPLY: u256 = 1_000_000 * E18;
const GAS_LIMIT: u256 = 10_000;
const TRANSFER_AMT: u256 = 100 * E18;
// const NAME: ByteArray = "HyperlaneInu";
// const SYMBOL: ByteArray = "HYP";
fn IGP() -> ContractAddress {
    starknet::contract_address_const::<'IGP'>()
}
fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}
fn ALICE() -> ContractAddress {
    starknet::contract_address_const::<0x1>()
}
fn BOB() -> ContractAddress {
    starknet::contract_address_const::<0x2>()
}
fn CAROL() -> ContractAddress {
    starknet::contract_address_const::<0x3>()
}
fn DANIEL() -> ContractAddress {
    starknet::contract_address_const::<0x4>()
}
fn PROXY_ADMIN() -> ContractAddress {
    starknet::contract_address_const::<0x37>()
}

pub fn NAME() -> ByteArray {
    "HyperlaneInu"
}
pub fn SYMBOL() -> ByteArray {
    "HYP"
}

#[derive(Copy, Drop)]
struct Setup {
    noop_hook: ITestPostDispatchHookDispatcher,
    local_mailbox: IMockMailboxDispatcher,
    remote_mailbox: IMockMailboxDispatcher,
    primary_token: ITestERC20Dispatcher,
    implementation: IHypErc20Dispatcher,
    remote_token: IHypErc20Dispatcher,
    local_token: IRouterDispatcher,
    igp: ITestInterchainGasPaymentDispatcher,
}

pub fn setup() -> Setup {
    let contract = declare("TestISM").unwrap();
    let (default_ism, _) = contract.deploy(@array![]).unwrap();

    let contract = declare("TestPostDispatchHook").unwrap();
    let (noop_hook, _) = contract.deploy(@array![]).unwrap();
    let noop_hook = ITestPostDispatchHookDispatcher { contract_address: noop_hook };

    let contract = declare("MockMailbox").unwrap();
    let (local_mailbox, _) = contract
        .deploy(@array![ORIGIN.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let local_mailbox = IMockMailboxDispatcher { contract_address: local_mailbox };

    let (remote_mailbox, _) = contract
        .deploy(@array![DESTINATION.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let remote_mailbox = IMockMailboxDispatcher { contract_address: remote_mailbox };

    local_mailbox.add_remote_mail_box(DESTINATION, remote_mailbox.contract_address);
    remote_mailbox.add_remote_mail_box(ORIGIN, local_mailbox.contract_address);

    local_mailbox.set_default_hook(noop_hook.contract_address);
    local_mailbox.set_required_hook(noop_hook.contract_address);
    remote_mailbox.set_default_hook(noop_hook.contract_address);
    remote_mailbox.set_required_hook(noop_hook.contract_address);

    let contract = declare("TestERC20").unwrap();
    let mut calldata: Array<felt252> = array![];
    TOTAL_SUPPLY.serialize(ref calldata);
    DECIMALS.serialize(ref calldata);
    let (primary_token, _) = contract.deploy(@calldata).unwrap();
    let primary_token = ITestERC20Dispatcher { contract_address: primary_token };

    let hyp_erc20_contract = declare("HypErc20").unwrap();
    let mut calldata: Array<felt252> = array![];
    TOTAL_SUPPLY.serialize(ref calldata);
    DECIMALS.serialize(ref calldata);
    remote_mailbox.contract_address.serialize(ref calldata);
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    noop_hook.contract_address.serialize(ref calldata);
    default_ism.serialize(ref calldata);
    OWNER().serialize(ref calldata);
    let (implementation, _) = hyp_erc20_contract.deploy(@calldata).unwrap();
    let implementation = IHypErc20Dispatcher { contract_address: implementation };

    let contract = declare("TestInterchainGasPayment").unwrap();
    let (igp, _) = contract.deploy(@array![]).unwrap();
    let igp = ITestInterchainGasPaymentDispatcher { contract_address: igp };

    let mut calldata: Array<felt252> = array![];
    TOTAL_SUPPLY.serialize(ref calldata);
    DECIMALS.serialize(ref calldata);
    remote_mailbox.contract_address.serialize(ref calldata);
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    noop_hook.contract_address.serialize(ref calldata);
    igp.contract_address.serialize(ref calldata);
    starknet::get_contract_address().serialize(ref calldata);
    let (remote_token, _) = hyp_erc20_contract.deploy(@calldata).unwrap();
    let remote_token = IHypErc20Dispatcher { contract_address: remote_token };

    let (local_token, _) = hyp_erc20_contract.deploy(@calldata).unwrap();
    let local_token = IRouterDispatcher { contract_address: local_token };

    let remote_token_router = IRouterDispatcher { contract_address: remote_token.contract_address };
    remote_token_router.enroll_remote_router(ORIGIN, 0x1);

    Setup {
        noop_hook,
        local_mailbox,
        remote_mailbox,
        primary_token,
        implementation,
        remote_token,
        local_token,
        igp
    }
}

pub fn enroll_local_router(setup: @Setup) {
    let remote_token_address: felt252 = (*setup).remote_token.contract_address.into();
    (*setup).local_token.enroll_remote_router(DESTINATION, remote_token_address.into());
}

pub fn enroll_remote_router(setup: @Setup) {
    let local_token_address: felt252 = (*setup).local_token.contract_address.into();
    let remote_token_router = IRouterDispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    remote_token_router.enroll_remote_router(ORIGIN, local_token_address.into());
}

pub fn connect_routers(setup: @Setup, domains: Span<u32>, addresses: Span<u256>) {
    let n = domains.len();

    let mut i: usize = 0;
    while i < n {
        let mut complement_domains: Array<u32> = array![];
        let mut complement_routers: Array<u256> = array![];

        let mut k: usize = 0;
        while k < n {
            if k != i {
                complement_domains.append(*domains.at(k));
                complement_routers.append(*addresses.at(k));
            }
            k += 1;
        };
        let address_felt: felt252 = (*addresses.at(i)).try_into().unwrap();
        let contract_address: ContractAddress = address_felt.try_into().unwrap();
        let router = IRouterDispatcher { contract_address };
        router.enroll_remote_routers(complement_domains, complement_routers);
        i += 1;
    };
}

pub fn expect_remote_balance(setup: @Setup, user: ContractAddress, balance: u256) {
    let remote_token = IERC20Dispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    assert_eq!(remote_token.balance_of(user), balance);
}

pub fn process_transfers(setup: @Setup, recipient: ContractAddress, amount: u256) {
    start_prank(
        CheatTarget::One((*setup).remote_token.contract_address),
        (*setup).remote_mailbox.contract_address
    );
    let mut message = BytesTrait::new_empty();
    message.append_address(recipient);
    message.append_u256(amount);
    let message_recipient = IMessageRecipientDispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    let address_felt: felt252 = recipient.into();
    let contract_address: u256 = address_felt.into();
    message_recipient.handle(ORIGIN, contract_address, message);
    stop_prank(CheatTarget::One((*setup).remote_token.contract_address));
}

pub fn handle_local_transfer(setup: @Setup, transfer_amount: u256) {
    start_prank(
        CheatTarget::One((*setup).local_token.contract_address),
        (*setup).local_mailbox.contract_address
    );
    let mut message = BytesTrait::new_empty();
    message.append_address(ALICE());
    message.append_u256(transfer_amount);
    let message_recipient = IMessageRecipientDispatcher {
        contract_address: (*setup).local_token.contract_address
    };
    let address_felt: felt252 = (*setup).remote_token.contract_address.into();
    let contract_address: u256 = address_felt.into();
    message_recipient.handle(DESTINATION, contract_address, message);
    stop_prank(CheatTarget::One((*setup).local_token.contract_address));
}

pub fn mint_and_approve(setup: @Setup, amount: u256, account: ContractAddress) {
    (*setup).primary_token._mint(amount);
    (*setup).primary_token.approve(account, amount);
}

pub fn set_custom_gas_config(setup: @Setup) {
    let mailbox_client = IMailboxClientDispatcher {
        contract_address: (*setup).local_token.contract_address
    };
    mailbox_client.set_hook((*setup).igp.contract_address);

    let config = array![GasRouterConfig { domain: DESTINATION, gas: GAS_LIMIT }];
    let gas_router = IGasRouterDispatcher {
        contract_address: (*setup).local_token.contract_address
    };
    gas_router.set_destination_gas(Option::Some(config), Option::None, Option::None);
}

pub fn perform_remote_transfer(setup: @Setup, msg_value: u256, amount: u256) {
    start_prank(CheatTarget::One((*setup).local_token.contract_address), ALICE());
    let token_router = ITokenRouterDispatcher {
        contract_address: (*setup).local_token.contract_address
    };

    let mut spy = spy_events(SpyOn::One((*setup).local_token.contract_address));

    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    token_router
        .transfer_remote(DESTINATION, bob_address, amount, msg_value, Option::None, Option::None);

    spy.fetch_events();
    let (from, event) = spy.events.at(0);
    assert(from == setup.local_token.contract_address, 'Emitted from wrong address');
    assert(event.keys.len() == 3, 'There should be one key');
    assert(event.keys.at(0) == @event_name_hash('SentTransferRemote'), 'Wrong event name');

    process_transfers(setup, BOB(), amount);

    let remote_token = IERC20Dispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    assert_eq!(remote_token.balance_of(BOB()), amount);

    stop_prank(CheatTarget::One((*setup).local_token.contract_address));
}

// NOTE: This is not applicable on Starknet
pub fn perform_remote_transfer_and_gas() {}

// NOTE: not implemented because it calls the above fn internally
pub fn perform_remote_transfer_with_emit() {}

pub fn perform_remote_transfer_and_gas_with_hook(
    setup: @Setup, msg_value: u256, amount: u256, hook: ContractAddress, hook_metadata: Bytes
) -> u256 {
    start_prank(CheatTarget::One((*setup).local_token.contract_address), ALICE());
    let token_router = ITokenRouterDispatcher {
        contract_address: (*setup).local_token.contract_address
    };
    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    let message_id = token_router
        .transfer_remote(
            DESTINATION,
            bob_address,
            amount,
            msg_value,
            Option::Some(hook_metadata),
            Option::Some(hook)
        );
    process_transfers(setup, BOB(), amount);

    let remote_token = IERC20Dispatcher {
        contract_address: (*setup).remote_token.contract_address
    };
    assert_eq!(remote_token.balance_of(BOB()), amount);
    stop_prank(CheatTarget::One((*setup).local_token.contract_address));
    message_id
}

pub fn test_transfer_with_hook_specified(setup: @Setup, fee: u256, metadata: Bytes) {
    let contract = declare("TestPostDispatchHook").unwrap();
    let (hook, _) = contract.deploy(@array![]).unwrap();
    let hook = ITestPostDispatchHookDispatcher { contract_address: hook };

    hook.set_fee(fee);

    start_prank(CheatTarget::One((*setup).primary_token.contract_address), ALICE());
    let primary_token = IERC20Dispatcher {
        contract_address: (*setup).primary_token.contract_address
    };
    primary_token.approve((*setup).local_token.contract_address, TRANSFER_AMT);

    let message_id = perform_remote_transfer_and_gas_with_hook(
        setup, 0, TRANSFER_AMT, hook.contract_address, metadata
    );

    assert!(hook.message_dispatched(message_id) == true, "Hook did not dispatch");
}

// NOTE: Not applicable on Starknet
fn test_benchmark_overhead_gas_usage() {}

#[test]
fn test_hyp_erc20_setup() {
    let _ = setup();
}
