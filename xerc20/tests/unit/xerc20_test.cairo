use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use xerc20::xerc20::interface::XERC20ABIDispatcher;

#[derive(Drop)]
pub struct Setup {
    owner: ContractAddress,
    user: ContractAddress,
    minter: ContractAddress,
    xerc20: XERC20ABIDispatcher,
    token_name: ByteArray,
    token_symbol: ByteArray,
}

pub fn setup() -> Setup {
    let owner = starknet::contract_address_const::<1>();
    let user = starknet::contract_address_const::<2>();
    let minter = starknet::contract_address_const::<3>();
    let token_name = "Test";
    let token_symbol = "TST";

    let xerc20_contract = declare("XERC20").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    token_name.serialize(ref ctor_calldata);
    token_symbol.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    let (xerc20_address, _) = xerc20_contract.deploy(@ctor_calldata).unwrap();

    Setup {
        owner,
        user,
        minter,
        xerc20: XERC20ABIDispatcher { contract_address: xerc20_address },
        token_name,
        token_symbol,
    }
}

pub mod unit_names {
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use super::setup;

    #[test]
    fn test_name() {
        let setup = setup();
        let xerc20 = ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address };
        assert!(xerc20.name() == setup.token_name, "Token name does not match!");
    }

    #[test]
    fn test_symbol() {
        let setup = setup();
        let xerc20 = ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address };
        assert!(xerc20.symbol() == setup.token_symbol, "Token symbol does not match!");
    }
}

pub mod unit_mint_burn {
    use core::num::traits::Bounded;
    use crate::common::{E40, U256MAX_DIV_2, bound};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;
    use xerc20::xerc20::interface::XERC20ABIDispatcherTrait;

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'User does not have enough limit')]
    fn test_mint_should_panic_when_not_approve(mut amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, Bounded::MAX);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.mint(setup.user, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'User does not have enough limit')]
    fn test_burn_should_panic_when_limit_is_too_low(mut amount_0: u256, mut amount_1: u256) {
        let setup = setup();
        amount_0 = bound(amount_0, 1, E40);
        amount_1 = bound(amount_1, amount_0 + 1, E40);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.user, amount_0, 0);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        // should revert since burning_limit eq zero
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.burn(setup.user, amount_1);
        stop_cheat_caller_address(setup.xerc20.contract_address);
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'Limits too high')]
    fn test_set_limit_should_panic_when_limit_is_too_high_after(mut limit: u256) {
        let setup = setup();
        limit = bound(limit, U256MAX_DIV_2 + 1, Bounded::MAX);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.user, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_mint(mut amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.user, amount, 0);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        let balance_prev = erc20_dispatcher.balance_of(setup.minter);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.mint(setup.minter, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let balance_after = erc20_dispatcher.balance_of(setup.minter);
        assert(balance_prev + amount == balance_after, 'Balances does not match!');
    }

    #[test]
    #[fuzzer]
    fn test_burn(mut amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, E40);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.user, amount, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        let balance_prev = erc20_dispatcher.balance_of(setup.user);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.mint(setup.user, amount);
        let balance_mid = erc20_dispatcher.balance_of(setup.user);
        assert(balance_prev + amount == balance_mid, 'Balances does not match!');
        setup.xerc20.burn(setup.user, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);
        let balance_after = erc20_dispatcher.balance_of(setup.user);
        assert(balance_prev == balance_after, 'Balances does not match!');
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'ERC20: insufficient allowance')]
    fn test_burn_should_panic_when_not_have_approval(mut amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, E40);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.user, amount, amount);
        setup.xerc20.burn(setup.user, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_burn_should_reduces_allowance(mut amount: u256, mut approval_amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, E40);
        approval_amount = bound(approval_amount, amount, 100_000 * E40);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.minter, amount, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.minter, approval_amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.minter);
        setup.xerc20.mint(setup.user, amount);
        setup.xerc20.burn(setup.user, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert(
            erc20_dispatcher.allowance(setup.user, setup.minter) == approval_amount - amount,
            'Allowance not reduced!',
        );
    }
}

pub mod unit_create_params {
    use core::num::traits::Zero;
    use crate::common::{E18, E40, HOUR, U256MAX_DIV_2, assert_approx_eq_rel, bound};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp_global,
        start_cheat_caller_address, stop_cheat_block_timestamp_global, stop_cheat_caller_address,
    };
    use starknet::ContractAddress;
    use super::setup;
    use xerc20::xerc20::{component::XERC20Component as XERC20, interface::XERC20ABIDispatcherTrait};

    #[test]
    #[fuzzer]
    fn test_should_change_limit(mut amount: u256, mut random_address_u128: u128) {
        let setup = setup();

        if random_address_u128.is_zero() {
            random_address_u128 = 0xBadCafe;
        }
        let mut random_address: ContractAddress = Into::<u128, felt252>::into(random_address_u128)
            .try_into()
            .unwrap();
        amount = bound(amount, 0, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(random_address, amount, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_max_limit_of(random_address) == amount,
            "MintingMaxLimitOf does not match!",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(random_address) == amount,
            "BurningMaxLimitOf does not match!",
        );
    }

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let setup = setup();
        setup.xerc20.set_limits(setup.minter, U256MAX_DIV_2, U256MAX_DIV_2);
    }

    #[test]
    #[fuzzer]
    fn test_should_add_minters_and_limits(
        mut amount_0: u256,
        mut amount_1: u256,
        mut amount_2: u256,
        mut user_0: u128,
        mut user_1: u128,
        mut user_2: u128,
    ) {
        let setup = setup();

        amount_0 = bound(amount_0, 1, U256MAX_DIV_2);
        amount_1 = bound(amount_1, 1, U256MAX_DIV_2);
        amount_2 = bound(amount_2, 1, U256MAX_DIV_2);
        if user_0 == user_1 {
            user_1 += 1;
        }
        if user_2 == user_1 || user_2 == user_0 {
            user_2 += 2
        }
        let user_0_address: ContractAddress = Into::<u128, felt252>::into(user_0)
            .try_into()
            .unwrap();
        let user_1_address: ContractAddress = Into::<u128, felt252>::into(user_1)
            .try_into()
            .unwrap();
        let user_2_address: ContractAddress = Into::<u128, felt252>::into(user_2)
            .try_into()
            .unwrap();
        let limits = array![amount_0, amount_1, amount_2];
        let minters = array![user_0_address, user_1_address, user_2_address];

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        for i in 0..limits.len() {
            setup.xerc20.set_limits(*minters[i], *limits[i], *limits[i]);
        };
        stop_cheat_caller_address(setup.xerc20.contract_address);

        for i in 0..limits.len() {
            assert!(
                setup.xerc20.minting_max_limit_of(*minters[i]) == *limits[i],
                "MintingMaxLimitOf does not match",
            );
            assert!(
                setup.xerc20.burning_max_limit_of(*minters[i]) == *limits[i],
                "BurningMaxLimitOf does not match",
            );
        };
    }

    #[test]
    #[fuzzer]
    fn test_change_bridge_minting_limit_emits_event(mut limit: u256, minter: u128) {
        let setup = setup();
        let minter_address: ContractAddress = Into::<u128, felt252>::into(minter)
            .try_into()
            .unwrap();
        limit = bound(limit, 0, U256MAX_DIV_2);
        let mut spy = spy_events();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, 0);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.xerc20.contract_address,
                        XERC20::Event::BridgeLimitsSet(
                            XERC20::BridgeLimitsSet {
                                minting_limit: limit, burning_limit: 0, bridge: minter_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    fn test_change_bridge_burning_limit_emits_event(mut limit: u256, minter: u128) {
        let setup = setup();
        let minter_address: ContractAddress = Into::<u128, felt252>::into(minter)
            .try_into()
            .unwrap();
        limit = bound(limit, 0, U256MAX_DIV_2);
        let mut spy = spy_events();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, 0, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.xerc20.contract_address,
                        XERC20::Event::BridgeLimitsSet(
                            XERC20::BridgeLimitsSet {
                                minting_limit: 0, burning_limit: limit, bridge: minter_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    fn test_setting_limits_to_unapproved_user(mut amount: u256) {
        let setup = setup();
        amount = bound(amount, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.minter, amount, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_max_limit_of(setup.minter) == amount,
            "Minting limit not setted correctly",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(setup.minter) == amount,
            "Burning limit not setted correctly",
        );
    }

    #[test]
    #[fuzzer]
    fn test_use_limit_updates_limit(mut limit: u256, mut minter_u128: u128) {
        let setup = setup();

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        limit = bound(limit, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, limit);
        setup.xerc20.burn(minter_address, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_max_limit_of(minter_address) == limit,
            "Minting limit not setted correctly",
        );
        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == 0,
            "Minting current limit not setted correctly",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(minter_address) == limit,
            "Burning limit not setted correctly",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(minter_address) == 0,
            "Burning current limit not setted correctly",
        );
    }

    #[test]
    #[fuzzer]
    fn test_current_limit_is_max_limit_if_unused(mut limit: u256, mut minter_u128: u128) {
        let setup = setup();

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        limit = bound(limit, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == limit,
            "Minting current limit does not match",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(minter_address) == limit,
            "Burning current limit does not match",
        );
        stop_cheat_block_timestamp_global();
    }

    #[test]
    #[fuzzer]
    fn test_current_limit_is_max_limit_if_over_24_hours(mut limit: u256, mut minter_u128: u128) {
        let setup = setup();

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        limit = bound(limit, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, limit);
        setup.xerc20.burn(minter_address, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 30 * HOUR);

        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == limit,
            "Minting current limit does not match",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(minter_address) == limit,
            "Burning current limit does not match",
        );

        stop_cheat_block_timestamp_global();
    }

    #[test]
    #[fuzzer]
    fn test_limit_vests_linearly(mut limit: u256, mut minter_u128: u128) {
        let setup = setup();

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();
        limit = bound(limit, 1_000_000, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, limit);
        setup.xerc20.burn(minter_address, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(minter_address), limit / 2, E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(minter_address), limit / 2, E18 / 10,
        );

        stop_cheat_block_timestamp_global();
    }

    #[test]
    #[fuzzer]
    fn test_overflow_limit_makes_it_max(
        mut limit: u256, mut minter_u128: u128, mut used_limit: u256,
    ) {
        let setup = setup();
        limit = bound(limit, 1_000_000, 100_000_000_000_000 * E18);
        used_limit = bound(used_limit, 0, 1_000);

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, used_limit);
        setup.xerc20.burn(minter_address, used_limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 20 * HOUR);

        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == limit,
            "Minting current limit does not match!",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(minter_address) == limit,
            "Burning current limit does not match!",
        );

        stop_cheat_block_timestamp_global();
    }

    #[test]
    #[fuzzer]
    fn test_change_bridge_minting_limit_increase_current_limit_by_the_difference_it_was_changed(
        mut limit: u256, mut minter_u128: u128, mut used_limit: u256,
    ) {
        let setup = setup();
        used_limit = bound(used_limit, 0, 1_000);
        limit = bound(limit, used_limit, E40);

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, used_limit);
        setup.xerc20.burn(minter_address, used_limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit + 100_000, limit + 100_000);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == (limit - used_limit) + 100_000,
            "Minting current limit does not match!",
        );
    }

    #[test]
    #[fuzzer]
    fn test_change_bridge_minting_limit_decrease_current_limit_by_the_difference_it_was_changed(
        mut limit: u256, mut minter_u128: u128, mut used_limit: u256,
    ) {
        let setup = setup();
        used_limit = bound(used_limit, 100_000, 1_000_000_000);
        limit = bound(limit, E18 / 1_000, E40);

        if minter_u128.is_zero() {
            minter_u128 = 0xBadCafe;
        }
        let mut minter_address: ContractAddress = Into::<u128, felt252>::into(minter_u128)
            .try_into()
            .unwrap();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, minter_address);
        setup.xerc20.mint(minter_address, used_limit);
        setup.xerc20.burn(minter_address, used_limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(minter_address, limit - 100_000, limit - 100_000);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_current_limit_of(minter_address) == (limit - used_limit) - 100_000,
            "Minting current limit does not match!",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(minter_address) == (limit - used_limit) - 100_000,
            "Burning current limit does not match!",
        );
    }

    #[test]
    #[fuzzer]
    fn test_changing_used_limits_to_zero(mut limit: u256, mut amount: u256) {
        let setup = setup();
        limit = bound(limit, 1, E40);
        amount = bound(amount, 0, limit);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.minter, limit, limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.minter);
        setup.xerc20.mint(setup.minter, amount);
        setup.xerc20.burn(setup.minter, amount);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.minter, 0, 0);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_max_limit_of(setup.minter) == 0, "Minting limit does not match!",
        );
        assert!(
            setup.xerc20.minting_current_limit_of(setup.minter) == 0,
            "Minting current limit does not match!",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(setup.minter) == 0, "Burning limit does not match!",
        );
        assert!(
            setup.xerc20.burning_current_limit_of(setup.minter) == 0,
            "Burning current limit does not match!",
        );
    }

    #[test]
    #[fuzzer]
    fn test_set_lockbox(mut lockbox: u128) {
        let setup = setup();
        let lockbox_address: ContractAddress = Into::<u128, felt252>::into(lockbox)
            .try_into()
            .unwrap();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_lockbox(lockbox_address);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.lockbox() == lockbox_address, "Lockbox addresses does not match!");
    }

    #[test]
    #[fuzzer]
    fn test_set_lockbox_emits_events(mut lockbox: u128) {
        let setup = setup();
        let lockbox_address: ContractAddress = Into::<u128, felt252>::into(lockbox)
            .try_into()
            .unwrap();

        let mut spy = spy_events();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_lockbox(lockbox_address);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.xerc20.contract_address,
                        XERC20::Event::LockboxSet(XERC20::LockboxSet { lockbox: lockbox_address }),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    fn test_lockbox_doesnt_need_minter_rights(mut lockbox_u128: u128) {
        let setup = setup();

        if lockbox_u128.is_zero() {
            lockbox_u128 = 0xBadCafe;
        }
        let mut lockbox_address: ContractAddress = Into::<u128, felt252>::into(lockbox_u128)
            .try_into()
            .unwrap();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_lockbox(lockbox_address);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, lockbox_address);
        setup.xerc20.mint(lockbox_address, 10);
        assert!(erc20_dispatcher.balance_of(lockbox_address) == 10, "Balances does not match!");
        setup.xerc20.burn(lockbox_address, 10);
        assert!(erc20_dispatcher.balance_of(lockbox_address) == 0, "Balances does not match!");
        stop_cheat_caller_address(setup.xerc20.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_remove_bridge(mut limit: u256) {
        let setup = setup();
        limit = bound(limit, 1, U256MAX_DIV_2);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.minter, limit, limit);

        assert!(
            setup.xerc20.minting_max_limit_of(setup.minter) == limit,
            "Minting limit does not match!",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(setup.minter) == limit,
            "Burning limit does not match!",
        );

        setup.xerc20.set_limits(setup.minter, 0, 0);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(
            setup.xerc20.minting_max_limit_of(setup.minter) == 0, "Minting limit does not match!",
        );
        assert!(
            setup.xerc20.burning_max_limit_of(setup.minter) == 0, "Burning limit does not match!",
        );
    }
}
