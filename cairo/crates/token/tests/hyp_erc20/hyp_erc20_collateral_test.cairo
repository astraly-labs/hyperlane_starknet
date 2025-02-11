use alexandria_bytes::{Bytes, BytesTrait};
use contracts::client::gas_router_component::{
    GasRouterComponent::GasRouterConfig, IGasRouterDispatcher, IGasRouterDispatcherTrait,
};
use contracts::utils::utils::U256TryIntoContractAddress;
use core::integer::BoundedInt;
use mocks::{
    mock_eth::{MockEthDispatcher, MockEthDispatcherTrait},
    mock_mailbox::{IMockMailboxDispatcher, IMockMailboxDispatcherTrait},
    test_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait},
    test_interchain_gas_payment::{
        ITestInterchainGasPaymentDispatcher, ITestInterchainGasPaymentDispatcherTrait,
    },
    test_post_dispatch_hook::{
        ITestPostDispatchHookDispatcher, ITestPostDispatchHookDispatcherTrait,
    },
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, spy_events,
};
use starknet::ContractAddress;
use super::common::{
    ALICE, BOB, DECIMALS, DESTINATION, E18, GAS_LIMIT, IHypERC20TestDispatcher,
    IHypERC20TestDispatcherTrait, ORIGIN, REQUIRED_VALUE, Setup, TOTAL_SUPPLY, TRANSFER_AMT,
    enroll_local_router, enroll_remote_router, perform_remote_transfer_and_gas,
    perform_remote_transfer_with_emit, set_custom_gas_config, setup,
};
use token::hyp_erc20_collateral::HypErc20Collateral;

fn setup_hyp_erc20_collateral() -> (IHypERC20TestDispatcher, Setup) {
    let setup = setup();
    let hyp_erc20_collateral_contract = declare("HypErc20Collateral").unwrap().contract_class();
    let constructor_args: Array<felt252> = array![
        setup.local_mailbox.contract_address.into(),
        setup.primary_token.contract_address.into(),
        ALICE().into(),
        setup.noop_hook.contract_address.into(),
        setup.primary_token.contract_address.into() // just a placeholder
    ];

    let (collateral_address, _) = hyp_erc20_collateral_contract.deploy(@constructor_args).unwrap();
    let collateral = IHypERC20TestDispatcher { contract_address: collateral_address };

    cheat_caller_address(
        setup.eth_token.contract_address, ALICE().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );

    IERC20Dispatcher { contract_address: setup.eth_token.contract_address }
        .approve(collateral_address, BoundedInt::max());

    // Enroll remote router
    let remote_token_address: felt252 = setup.remote_token.contract_address.into();
    cheat_caller_address(
        collateral.contract_address, ALICE().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    collateral.enroll_remote_router(DESTINATION, remote_token_address.into());

    // Transfer tokens to collateral contract and ALICE
    setup.primary_token.transfer(collateral.contract_address, 1000 * E18);
    setup.primary_token.transfer(ALICE(), 1000 * E18);
    let addr: felt252 = collateral.contract_address.into();
    // Enroll remote router for the remote token
    setup.remote_token.enroll_remote_router(ORIGIN, addr.into());
    (collateral, setup)
}

fn perform_remote_transfer_collateral(
    setup: @Setup,
    collateral: @IHypERC20TestDispatcher,
    msg_value: u256,
    extra_gas: u256,
    amount: u256,
    approve: bool,
) {
    // Approve
    if approve {
        cheat_caller_address(
            *setup.primary_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
        );
        (*setup.primary_token).approve(*collateral.contract_address, amount);
    }
    // Remote transfer
    cheat_caller_address(*collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    (*collateral)
        .transfer_remote(DESTINATION, bob_address, amount, msg_value, Option::None, Option::None);

    process_transfers_collateral(setup, collateral, BOB(), amount);

    let remote_token = IERC20Dispatcher {
        contract_address: (*setup).remote_token.contract_address,
    };
    assert_eq!(remote_token.balance_of(BOB()), amount);
}

fn process_transfers_collateral(
    setup: @Setup, collateral: @IHypERC20TestDispatcher, recipient: ContractAddress, amount: u256,
) {
    cheat_caller_address(
        (*setup).remote_token.contract_address,
        (*setup).remote_mailbox.contract_address,
        CheatSpan::TargetCalls(1),
    );

    let local_token_address: felt252 = (*collateral).contract_address.into();
    let mut message = BytesTrait::new_empty();
    message.append_address(recipient);
    message.append_u256(amount);
    (*setup).remote_token.handle(ORIGIN, local_token_address.into(), message);
}

#[test]
fn test_remote_transfer() {
    let (collateral, setup) = setup_hyp_erc20_collateral();
    let balance_before = collateral.balance_of(ALICE());
    cheat_caller_address(collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    perform_remote_transfer_collateral(@setup, @collateral, REQUIRED_VALUE, 0, TRANSFER_AMT, true);
    // Check balance after transfer
    assert_eq!(
        collateral.balance_of(ALICE()),
        balance_before - TRANSFER_AMT,
        "Incorrect balance after transfer",
    );
}

#[test]
#[should_panic]
fn test_remote_transfer_invalid_allowance() {
    let (collateral, setup) = setup_hyp_erc20_collateral();
    cheat_caller_address(collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    perform_remote_transfer_collateral(@setup, @collateral, REQUIRED_VALUE, 0, TRANSFER_AMT, false);
}

#[test]
fn test_remote_transfer_with_custom_gas_config() {
    let (collateral, setup) = setup_hyp_erc20_collateral();
    // Check balance before transfer
    let balance_before = collateral.balance_of(ALICE());
    cheat_caller_address(collateral.contract_address, ALICE(), CheatSpan::TargetCalls(2));

    // Set custom gas config
    collateral.set_hook(setup.igp.contract_address);
    let config = array![GasRouterConfig { domain: DESTINATION, gas: GAS_LIMIT }];
    collateral.set_destination_gas(Option::Some(config), Option::None, Option::None);
    // Do a remote transfer
    perform_remote_transfer_collateral(
        @setup, @collateral, REQUIRED_VALUE, setup.igp.gas_price(), TRANSFER_AMT, true,
    );

    // Check balance after transfer
    assert_eq!(
        collateral.balance_of(ALICE()),
        balance_before - TRANSFER_AMT,
        "Incorrect balance after transfer",
    );
}
