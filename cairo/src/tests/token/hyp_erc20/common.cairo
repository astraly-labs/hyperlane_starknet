use hyperlane_starknet::interfaces::{IMailboxDispatcher, IMailboxDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn
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

pub fn setup() {
    let contract = declare("TestISM").unwrap();
    let (default_ism, _) = contract.deploy(@array![]).unwrap();

    let contract = declare("TestPostDispatchHook").unwrap();
    let (post_dispatch_hook, _) = contract.deploy(@array![]).unwrap();

    let contract = declare("MockMailbox").unwrap();
    let (local_mailbox, _) = contract
        .deploy(@array![ORIGIN.into(), default_ism.into(), post_dispatch_hook.into(),])
        .unwrap();

    let contract = declare("TestERC20").unwrap();
    let calldata: Array<felt252> = array![
        TOTAL_SUPPLY.low.into(), TOTAL_SUPPLY.high.into(), DECIMALS.into(),
    ];
    let (primary_token, _) = contract.deploy(@calldata).unwrap();

    let contract = declare("TestPostDispatchHook").unwrap();
// let (post_dispatch_hook, _) = contract.deploy(@array![]).unwrap();
}

#[test]
fn test_hyp_erc20_setup() {
    setup();
}
