use hyperlane_starknet::contracts::mocks::{
    test_post_dispatch_hook::{
        ITestPostDispatchHookDispatcher, ITestPostDispatchHookDispatcherTrait
    },
    mock_mailbox::{IMockMailboxDispatcher, IMockMailboxDispatcherTrait},
    test_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait},
    test_interchain_gas_payment::{ITestInterchainGasPaymentDispatcher, ITestInterchainGasPaymentDispatcherTrait},
};
use hyperlane_starknet::contracts::token::components::hyp_erc20_component::{
    IHypErc20Dispatcher, IHypErc20DispatcherTrait
};
use hyperlane_starknet::interfaces::{IMailboxDispatcher, IMailboxDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn
};
use hyperlane_starknet::contracts::client::router_component::{IRouterDispatcher, IRouterDispatcherTrait};
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

#[derive(Drop)]
struct Setup {
    noop_hook: ITestPostDispatchHookDispatcher,
    local_mailbox: IMockMailboxDispatcher,
    remote_mailbox: IMockMailboxDispatcher,
    primary_token: ITestERC20Dispatcher,
    implementation: IHypErc20Dispatcher,
    remote_token: IHypErc20Dispatcher,
    igp: ITestInterchainGasPaymentDispatcher,
}

pub fn setup() -> Setup {
    let contract = declare("TestISM").unwrap();
    let (default_ism, _) = contract.deploy(@array![]).unwrap();

    let contract = declare("TestPostDispatchHook").unwrap();
    let (noop_hook, _) = contract.deploy(@array![]).unwrap();
    let noop_hook = ITestPostDispatchHookDispatcher{contract_address: noop_hook};

    let contract = declare("MockMailbox").unwrap();
    let (local_mailbox, _) = contract
        .deploy(@array![ORIGIN.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let local_mailbox = IMockMailboxDispatcher{contract_address: local_mailbox};

    let (remote_mailbox, _) = contract
        .deploy(@array![DESTINATION.into(), default_ism.into(), noop_hook.contract_address.into(),])
        .unwrap();
    let remote_mailbox = IMockMailboxDispatcher{contract_address: remote_mailbox};

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
    let primary_token = ITestERC20Dispatcher{contract_address: primary_token};

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
    let implementation = IHypErc20Dispatcher{contract_address: implementation};


    let contract = declare("TestInterchainGasPayment").unwrap();
    let (igp, _) = contract.deploy(@array![]).unwrap();
    let igp = ITestInterchainGasPaymentDispatcher{contract_address: igp};

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
    let remote_token = IHypErc20Dispatcher{contract_address: remote_token};

    let remote_token_router = IRouterDispatcher{contract_address: remote_token.contract_address};
    remote_token_router.enroll_remote_router(ORIGIN, 0x1);

    Setup {
        noop_hook,
        local_mailbox,
        remote_mailbox,
        primary_token,
        implementation,
        remote_token,
        igp,
    }
}


#[test]
fn test_hyp_erc20_setup() {
    let setup = setup();
}
