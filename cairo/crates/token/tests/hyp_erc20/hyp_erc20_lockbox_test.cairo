use alexandria_bytes::{Bytes, BytesTrait};
use contracts::client::gas_router_component::GasRouterComponent::GasRouterConfig;
use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::VARIANT;
use core::integer::BoundedInt;
use mocks::test_interchain_gas_payment::ITestInterchainGasPaymentDispatcherTrait;
use mocks::{
    test_erc20::ITestERC20DispatcherTrait,
    test_post_dispatch_hook::{
        ITestPostDispatchHookDispatcher, ITestPostDispatchHookDispatcherTrait,
    },
    xerc20_lockbox_test::IXERC20LockboxTestDispatcher, xerc20_test::IXERC20TestDispatcher,
};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::ContractAddress;
use super::common::{
    ALICE, BOB, DECIMALS, DESTINATION, E18, GAS_LIMIT, IHypERC20TestDispatcherTrait, ORIGIN,
    REQUIRED_VALUE, Setup, TRANSFER_AMT, ZERO_SUPPLY, setup,
};

const MAX_INT: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

#[starknet::interface]
pub trait IHypERC20LockboxTest<TContractState> {
    // MailboxClient
    fn set_hook(ref self: TContractState, _hook: ContractAddress);
    fn set_interchain_security_module(ref self: TContractState, _module: ContractAddress);
    fn get_hook(self: @TContractState) -> ContractAddress;
    fn get_local_domain(self: @TContractState) -> u32;
    fn interchain_security_module(self: @TContractState) -> ContractAddress;
    // Router
    fn enroll_remote_router(ref self: TContractState, domain: u32, router: u256);
    fn enroll_remote_routers(ref self: TContractState, domains: Array<u32>, addresses: Array<u256>);
    fn unenroll_remote_router(ref self: TContractState, domain: u32);
    fn unenroll_remote_routers(ref self: TContractState, domains: Array<u32>);
    fn handle(ref self: TContractState, origin: u32, sender: u256, message: Bytes);
    fn domains(self: @TContractState) -> Array<u32>;
    fn routers(self: @TContractState, domain: u32) -> u256;
    // GasRouter
    fn set_destination_gas(
        ref self: TContractState,
        gas_configs: Option<Array<GasRouterConfig>>,
        domain: Option<u32>,
        gas: Option<u256>,
    );
    fn quote_gas_payment(self: @TContractState, destination_domain: u32) -> u256;
    // TokenRouter
    fn transfer_remote(
        ref self: TContractState,
        destination: u32,
        recipient: u256,
        amount_or_id: u256,
        value: u256,
        hook_metadata: Option<Bytes>,
        hook: Option<ContractAddress>,
    ) -> u256;
    // XERC20Lockbox
    fn xerc20(self: @TContractState) -> ContractAddress;
    fn erc20(self: @TContractState) -> ContractAddress;
    fn deposit(ref self: TContractState, amount: u256);
    fn deposit_to(ref self: TContractState, user: u256, amount: u256);
    fn deposit_native_to(ref self: TContractState, user: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn withdraw_to(ref self: TContractState, user: u256, amount: u256);
    fn lockbox(self: @TContractState) -> ContractAddress;
    fn xERC20(self: @TContractState) -> ContractAddress;
    // HypERC20Collateral
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

fn setup_lockbox() -> (Setup, IHypERC20LockboxTestDispatcher) {
    let mut setup = setup();

    let mut calldata: Array<felt252> = array![];
    ZERO_SUPPLY.serialize(ref calldata);
    DECIMALS.serialize(ref calldata);

    let contract = declare("XERC20Test").unwrap().contract_class();
    let (xerc20, _) = contract.deploy(@calldata).unwrap();
    let xerc20 = IXERC20TestDispatcher { contract_address: xerc20 };

    let contract = declare("XERC20LockboxTest").unwrap().contract_class();

    let mut calldata: Array<felt252> = array![];
    xerc20.contract_address.serialize(ref calldata);
    setup.erc20_token.contract_address.serialize(ref calldata);

    let (lockbox, _) = contract.deploy(@calldata).unwrap();
    let lockbox = IXERC20LockboxTestDispatcher { contract_address: lockbox };
    let contract = declare("HypXERC20Lockbox").unwrap().contract_class();

    let mut calldata: Array<felt252> = array![];
    setup.local_mailbox.contract_address.serialize(ref calldata);
    lockbox.contract_address.serialize(ref calldata);
    starknet::get_contract_address().serialize(ref calldata);
    setup.noop_hook.contract_address.serialize(ref calldata);
    setup.igp.contract_address.serialize(ref calldata);

    let (xerc20lockbox, _) = contract.deploy(@calldata).unwrap();
    let xerc20lockbox = IHypERC20LockboxTestDispatcher { contract_address: xerc20lockbox };

    cheat_caller_address(setup.eth_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));

    ERC20ABIDispatcher { contract_address: setup.eth_token.contract_address }
        .approve(xerc20.contract_address, BoundedInt::max());
    ERC20ABIDispatcher { contract_address: setup.eth_token.contract_address }
        .approve(lockbox.contract_address, BoundedInt::max());
    ERC20ABIDispatcher { contract_address: setup.eth_token.contract_address }
        .approve(xerc20lockbox.contract_address, BoundedInt::max());

    let remote_token_address: felt252 = setup.remote_token.contract_address.into();
    xerc20lockbox.enroll_remote_router(DESTINATION, remote_token_address.into());
    setup.primary_token = setup.erc20_token;
    setup.primary_token.transfer(ALICE(), 1000 * E18);
    enroll_remote_router(@setup, xerc20lockbox);
    (setup, xerc20lockbox)
}

#[test]
fn test_erc20_lockbox_approval() {
    let (_, xerc20lockbox) = setup_lockbox();

    let xerc20 = xerc20lockbox.xERC20();
    let dispatcher = ERC20ABIDispatcher { contract_address: xerc20 };
    assert_eq!(
        dispatcher.allowance(xerc20lockbox.contract_address, xerc20lockbox.lockbox()), MAX_INT,
    );
}

#[test]
fn test_erc20_lockbox_transfer() {
    let (setup, xerc20lockbox) = setup_lockbox();

    let balance_before = xerc20lockbox.balance_of(ALICE());

    cheat_caller_address(setup.primary_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    setup.primary_token.approve(xerc20lockbox.contract_address, TRANSFER_AMT);
    perform_remote_transfer_and_gas(@setup, xerc20lockbox, REQUIRED_VALUE, TRANSFER_AMT, 0);

    assert_eq!(xerc20lockbox.balance_of(ALICE()), balance_before - TRANSFER_AMT);
}

#[test]
fn test_remote_transfer_with_custom_gas_config() {
    let (setup, xerc20lockbox) = setup_lockbox();
    let gas_price = setup.igp.gas_price();

    cheat_caller_address(setup.eth_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));

    let eth_dispatcher = IERC20Dispatcher { contract_address: setup.eth_token.contract_address };
    eth_dispatcher.approve(xerc20lockbox.contract_address, gas_price * GAS_LIMIT);

    cheat_caller_address(setup.primary_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    setup.primary_token.approve(xerc20lockbox.contract_address, TRANSFER_AMT);

    println!(
        "allowance {:?} {:?}",
        setup.primary_token.allowance(ALICE(), xerc20lockbox.contract_address),
        xerc20lockbox.contract_address,
    );

    // Check balance before transfer
    let balance_before = xerc20lockbox.balance_of(ALICE());
    // Set custom gas config
    xerc20lockbox.set_hook(setup.igp.contract_address);
    let config = array![GasRouterConfig { domain: DESTINATION, gas: GAS_LIMIT }];
    xerc20lockbox.set_destination_gas(Option::Some(config), Option::None, Option::None);

    cheat_caller_address(xerc20lockbox.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    // Do a remote transfer
    perform_remote_transfer_and_gas(
        @setup, xerc20lockbox, REQUIRED_VALUE, TRANSFER_AMT, GAS_LIMIT * gas_price,
    );

    // Check balance after transfer
    assert_eq!(
        xerc20lockbox.balance_of(ALICE()),
        balance_before - TRANSFER_AMT,
        "Incorrect balance after transfer",
    );
    let eth_dispatcher = IERC20Dispatcher { contract_address: setup.eth_token.contract_address };
    assert_eq!(
        eth_dispatcher.balance_of(setup.igp.contract_address),
        GAS_LIMIT * gas_price,
        "Gas fee didnt transferred",
    );
}

pub fn perform_remote_transfer_erc20_lockbox_and_gas_with_hook(
    setup: @Setup,
    local_token: IHypERC20LockboxTestDispatcher,
    msg_value: u256,
    amount: u256,
    hook: ContractAddress,
    hook_metadata: Bytes,
) -> u256 {
    cheat_caller_address(local_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    // Remote transfer
    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    let message_id = local_token
        .transfer_remote(
            DESTINATION,
            bob_address,
            amount,
            msg_value,
            Option::Some(hook_metadata),
            Option::Some(hook),
        );

    process_transfers(setup, local_token, BOB(), amount);

    let remote_token = IERC20Dispatcher {
        contract_address: (*setup).remote_token.contract_address,
    };
    assert_eq!(remote_token.balance_of(BOB()), amount);
    message_id
}

#[test]
#[fuzzer]
fn test_fuzz_erc20_lockbox_remote_transfer_with_hook_specified(mut fee: u256, metadata: u256) {
    let fee = fee % (TRANSFER_AMT / 10);
    let mut metadata_bytes = BytesTrait::new_empty();
    metadata_bytes.append_u16(VARIANT);
    metadata_bytes.append_u256(metadata);
    let (setup, xerc20lockbox) = setup_lockbox();

    let (hook_address, _) = setup.test_post_dispatch_hook_contract.deploy(@array![]).unwrap();
    let hook = ITestPostDispatchHookDispatcher { contract_address: hook_address };
    hook.set_fee(fee);

    cheat_caller_address(setup.eth_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));

    let eth_dispatcher = IERC20Dispatcher { contract_address: setup.eth_token.contract_address };
    eth_dispatcher.approve(xerc20lockbox.contract_address, fee);

    cheat_caller_address(setup.primary_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    setup.primary_token.approve(xerc20lockbox.contract_address, TRANSFER_AMT);

    let balance_before = xerc20lockbox.balance_of(ALICE());

    let message_id = perform_remote_transfer_erc20_lockbox_and_gas_with_hook(
        @setup, xerc20lockbox, fee, TRANSFER_AMT, hook.contract_address, metadata_bytes,
    );

    let balance_after = xerc20lockbox.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
    assert_eq!(eth_dispatcher.balance_of(hook_address), fee, "fee didnt transferred");
    assert!(hook.message_dispatched(message_id), "Hook did not dispatch");
}

#[test]
fn test_erc20_lockbox_handle() {
    let (setup, local_token) = setup_lockbox();

    let balance_before = local_token.balance_of(ALICE());

    handle_local_transfer(@setup, local_token, TRANSFER_AMT);

    assert_eq!(local_token.balance_of(ALICE()), balance_before + TRANSFER_AMT);
}

pub fn handle_local_transfer(
    setup: @Setup, local_token: IHypERC20LockboxTestDispatcher, transfer_amount: u256,
) {
    cheat_caller_address(
        local_token.contract_address,
        (*setup).local_mailbox.contract_address,
        CheatSpan::TargetCalls(1),
    );

    let mut message = BytesTrait::new_empty();
    message.append_address(ALICE());
    message.append_u256(transfer_amount);

    let address_felt: felt252 = (*setup).remote_token.contract_address.into();
    let contract_address: u256 = address_felt.into();
    local_token.handle(DESTINATION, contract_address, message);
}

pub fn enroll_remote_router(setup: @Setup, lockbox: IHypERC20LockboxTestDispatcher) {
    let local_token_address: felt252 = lockbox.contract_address.into();
    (*setup).remote_token.enroll_remote_router(ORIGIN, local_token_address.into());
}


pub fn perform_remote_transfer(
    setup: @Setup, local_token: IHypERC20LockboxTestDispatcher, msg_value: u256, amount: u256,
) {
    cheat_caller_address(local_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    local_token
        .transfer_remote(DESTINATION, bob_address, amount, msg_value, Option::None, Option::None);
    process_transfers(setup, local_token, BOB(), amount);

    let remote_token = ERC20ABIDispatcher {
        contract_address: (*setup).remote_token.contract_address,
    };
    assert_eq!(remote_token.balance_of(BOB()), amount);
}

pub fn perform_remote_transfer_and_gas(
    setup: @Setup,
    local_token: IHypERC20LockboxTestDispatcher,
    msg_value: u256,
    amount: u256,
    gas_overhead: u256,
) {
    perform_remote_transfer(setup, local_token, msg_value + gas_overhead, amount);
}

pub fn process_transfers(
    setup: @Setup,
    local_token: IHypERC20LockboxTestDispatcher,
    recipient: ContractAddress,
    amount: u256,
) {
    cheat_caller_address(
        (*setup).remote_token.contract_address,
        (*setup).remote_mailbox.contract_address,
        CheatSpan::TargetCalls(1),
    );

    let mut message = BytesTrait::new_empty();
    message.append_address(recipient);
    message.append_u256(amount);
    let address_felt: felt252 = local_token.contract_address.into();
    let local_token_address: u256 = address_felt.into();
    (*setup).remote_token.handle(ORIGIN, local_token_address, message);
}
