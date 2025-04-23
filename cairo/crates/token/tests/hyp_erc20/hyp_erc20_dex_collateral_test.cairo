use alexandria_bytes::BytesTrait;
use contracts::client::gas_router_component::GasRouterComponent::GasRouterConfig;
use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::VARIANT;
use contracts::utils::utils::U256TryIntoContractAddress;
use core::integer::BoundedInt;
use mocks::{
    mock_paradex_dex::{IMockParadexDexDispatcher, IMockParadexDexDispatcherTrait, MockParadexDex},
    test_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait},
    test_interchain_gas_payment::ITestInterchainGasPaymentDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events,
};
use starknet::ContractAddress;
use super::common::DECIMALS;
use super::common::TOTAL_SUPPLY;
use super::common::{
    ALICE, BOB, DESTINATION, E18, GAS_LIMIT, IHypERC20TestDispatcher, IHypERC20TestDispatcherTrait,
    ORIGIN, REQUIRED_VALUE, Setup, TRANSFER_AMT, setup,
};
use token::extensions::hyp_erc20_dex_collateral::{
    IHypErc20DexCollateralDispatcher, IHypErc20DexCollateralDispatcherTrait,
};

#[derive(Copy, Drop)]
pub struct DexSetup {
    pub setup: Setup,
    pub paradex_usdc: ITestERC20Dispatcher,
    pub dex: IMockParadexDexDispatcher,
    pub remote_dex_collateral: IHypERC20TestDispatcher,
    pub collateral: IHypERC20TestDispatcher,
}


// Setup for DEX collateral tests
fn setup_dex_collateral() -> DexSetup {
    let setup = setup();

    let contract = declare("TestERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    TOTAL_SUPPLY.serialize(ref calldata);
    DECIMALS.serialize(ref calldata);
    let (paradex_usdc, _) = contract.deploy(@calldata).unwrap();
    let paradex_usdc = ITestERC20Dispatcher { contract_address: paradex_usdc };
    // mint 1000 to this contract
    paradex_usdc.mint(starknet::get_contract_address(), 1000000 * E18);
    paradex_usdc.approve(paradex_usdc.contract_address, 1000000 * E18);

    // Deploy the mock DEX
    let mock_dex_contract = declare("MockParadexDex").unwrap().contract_class();
    let (dex_address, _) = mock_dex_contract.deploy(@array![]).unwrap();
    let dex = IMockParadexDexDispatcher { contract_address: dex_address };

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

    // Deploy the HypErc20DexCollateral contract
    let hyp_erc20_dex_collateral_contract = declare("HypErc20DexCollateral")
        .unwrap()
        .contract_class();
    let constructor_args: Array<felt252> = array![
        setup.remote_mailbox.contract_address.into(),
        dex_address.into(),
        paradex_usdc.contract_address.into(),
        ALICE().into(),
        setup.noop_hook.contract_address.into(),
        paradex_usdc.contract_address.into() // placeholder for ISM
    ];

    let (remote_dex_collateral_address, _) = hyp_erc20_dex_collateral_contract
        .deploy(@constructor_args)
        .unwrap();
    let remote_dex_collateral = IHypERC20TestDispatcher {
        contract_address: remote_dex_collateral_address,
    };
    dex.set_hyperlane_token(paradex_usdc.contract_address);

    let local_token_address: felt252 = collateral.contract_address.into();
    cheat_caller_address(
        remote_dex_collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    remote_dex_collateral.enroll_remote_router(ORIGIN, local_token_address.into());

    // enroll local router
    let remote_token_address: felt252 = remote_dex_collateral.contract_address.into();
    cheat_caller_address(collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    collateral.enroll_remote_router(DESTINATION, remote_token_address.into());

    setup.primary_token.transfer(ALICE(), 1000 * E18);
    paradex_usdc.transfer(remote_dex_collateral.contract_address, 1000000 * E18);

    DexSetup { setup, paradex_usdc, dex, remote_dex_collateral, collateral }
}

// perform transfer from local
fn perform_remote_transfer_dex(setup: @DexSetup, msg_value: u256, amount: u256, approve: bool) {
    // Approve tokens if needed
    if approve {
        cheat_caller_address(
            (*setup).setup.primary_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
        );
        (*setup).setup.primary_token.approve((*setup).collateral.contract_address, amount);
    }

    cheat_caller_address((*setup).collateral.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    let bob_felt: felt252 = BOB().into();
    let bob_address: u256 = bob_felt.into();
    (*setup)
        .collateral
        .transfer_remote(DESTINATION, bob_address, amount, msg_value, Option::None, Option::None);

    process_transfers_dex(setup, BOB(), amount);
}

// process handle on remote
fn process_transfers_dex(setup: @DexSetup, recipient: ContractAddress, amount: u256) {
    cheat_caller_address(
        (*setup).remote_dex_collateral.contract_address,
        (*setup).setup.remote_mailbox.contract_address,
        CheatSpan::TargetCalls(1),
    );

    let local_token_address: felt252 = (*setup).collateral.contract_address.into();
    let mut message = BytesTrait::new_empty();
    message.append_address(recipient);
    message.append_u256(amount);
    (*setup).remote_dex_collateral.handle(ORIGIN, local_token_address.into(), message);
}

#[test]
fn test_dex_contract_setup() {
    let setup = setup_dex_collateral();

    let dex_collateral = IHypErc20DexCollateralDispatcher {
        contract_address: setup.remote_dex_collateral.contract_address,
    };
    assert_eq!(dex_collateral.get_dex(), setup.dex.contract_address, "DEX address mismatch");

    let deposit_token = dex_collateral.get_deposit_token();
    assert_eq!(deposit_token, setup.paradex_usdc.contract_address, "Collateral token not set");
}

#[test]
fn test_remote_transfer_dex() {
    let setup = setup_dex_collateral();
    let mut spy = spy_events();

    let balance_before = setup.setup.primary_token.balance_of(ALICE());

    perform_remote_transfer_dex(@setup, REQUIRED_VALUE, TRANSFER_AMT, true);

    assert_eq!(
        setup.setup.primary_token.balance_of(ALICE()),
        balance_before - TRANSFER_AMT,
        "Incorrect balance after transfer",
    );

    spy
        .assert_emitted(
            @array![
                (
                    setup.dex.contract_address,
                    MockParadexDex::Event::DepositSuccess(
                        MockParadexDex::DepositSuccess {
                            token: setup.paradex_usdc.contract_address,
                            recipient: BOB(),
                            amount: TRANSFER_AMT,
                        },
                    ),
                ),
            ],
        );

    let balance_after = setup.paradex_usdc.balance_of(BOB());
    assert_eq!(balance_after, 0, "Balance shouldn't be transferred directly BOB");
}

#[test]
#[should_panic]
fn test_remote_transfer_dex_invalid_allowance() {
    let setup = setup_dex_collateral();
    perform_remote_transfer_dex(@setup, REQUIRED_VALUE, TRANSFER_AMT, false);
}

#[test]
fn test_dex_collateral_with_custom_gas_config() {
    let setup = setup_dex_collateral();
    let balance_before = setup.collateral.balance_of(ALICE());
    cheat_caller_address(setup.collateral.contract_address, ALICE(), CheatSpan::TargetCalls(2));

    setup.collateral.set_hook(setup.setup.igp.contract_address);
    let config = array![GasRouterConfig { domain: DESTINATION, gas: GAS_LIMIT }];
    setup.collateral.set_destination_gas(Option::Some(config), Option::None, Option::None);
    let gas_price = setup.setup.igp.gas_price();

    let eth_dispatcher = IERC20Dispatcher {
        contract_address: setup.setup.eth_token.contract_address,
    };
    cheat_caller_address(
        setup.setup.eth_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    eth_dispatcher.approve(setup.collateral.contract_address, GAS_LIMIT * gas_price);

    perform_remote_transfer_dex(@setup, REQUIRED_VALUE + GAS_LIMIT * gas_price, TRANSFER_AMT, true);

    assert_eq!(
        setup.collateral.balance_of(ALICE()),
        balance_before - TRANSFER_AMT,
        "Incorrect balance after transfer",
    );
    // assert_eq!(
    //     setup.paradex_usdc.balance_of(BOB()), TRANSFER_AMT, "Incorrect balance after transfer",
    // );
    assert_eq!(
        eth_dispatcher.balance_of(setup.setup.igp.contract_address),
        GAS_LIMIT * gas_price,
        "Gas fee wasn't transferred",
    );
}

#[test]
fn test_balance_of() {
    let setup = setup_dex_collateral();

    perform_remote_transfer_dex(@setup, REQUIRED_VALUE, TRANSFER_AMT, true);

    let dex_collateral = IHypErc20DexCollateralDispatcher {
        contract_address: setup.remote_dex_collateral.contract_address,
    };

    let balance_after = dex_collateral.balance_on_behalf_of(BOB());
    assert_eq!(balance_after, TRANSFER_AMT, "Incorrect balance after transfer");
}
