pub mod e2e_mint_and_burn {
    use crate::{common::{DAY, E18}, e2e::common::{prepare_permit_signature, setup_base}};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use xerc20::xerc20::interface::XERC20ABIDispatcherTrait;

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_mint() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 0);
        setup.xerc20.mint(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        assert!(erc20_dispatcher.balance_of(setup.user) == 100 * E18, "Balance mismatch!");
        assert!(erc20_dispatcher.total_supply() == 100 * E18, "Total supply mismatch!");
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_burn() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        setup.xerc20.mint(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);
        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(erc20_dispatcher.balance_of(setup.user) == 0, "Balance mismatch!");
        assert!(erc20_dispatcher.total_supply() == 0, "Total supply mismatch!");
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_burn_w_permit() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        setup.xerc20.mint(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);
        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };

        let deadline = starknet::get_block_timestamp() + DAY;
        let user_permit_sig = prepare_permit_signature(@setup, setup.owner, 100 * E18, deadline);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        erc20_dispatcher.permit(setup.user, setup.owner, 100 * E18, deadline, user_permit_sig);
        assert!(erc20_dispatcher.allowance(setup.user, setup.owner) == 100 * E18);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(erc20_dispatcher.balance_of(setup.user) == 0, "Balance mismatch!");
        assert!(erc20_dispatcher.total_supply() == 0, "Total supply mismatch!");
    }
}

pub mod e2e_parameter_math {
    use crate::{common::{E18, HOUR, assert_approx_eq_rel}, e2e::common::setup_base};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use snforge_std::{
        start_cheat_block_timestamp_global, start_cheat_caller_address,
        stop_cheat_block_timestamp_global, stop_cheat_caller_address,
    };
    use xerc20::xerc20::interface::XERC20ABIDispatcherTrait;

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_should_change_limit() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 100 * E18);
        assert!(setup.xerc20.burning_max_limit_of(setup.owner) == 100 * E18);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_adding_minters_and_limits() {
        let setup = setup_base();

        let limits = array![100 * E18, 100 * E18, 100 * E18];
        let minters = array![
            starknet::contract_address_const::<'minter_1'>(),
            starknet::contract_address_const::<'minter_2'>(),
            starknet::contract_address_const::<'minter_3'>(),
        ];
        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        for i in 0..limits.len() {
            setup.xerc20.set_limits(*minters[i], *limits[i], *limits[i]);
        };
        stop_cheat_caller_address(setup.xerc20.contract_address);
        for i in 0..limits.len() {
            assert!(setup.xerc20.minting_max_limit_of(*minters[i]) == *limits[i]);
        };
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_should_use_limits_updates_limits() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 100 * E18);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 0);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 0);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_should_changing_max_limit_updates_current_limit() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);

        setup.xerc20.set_limits(setup.owner, 50 * E18, 50 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 50 * E18);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 50 * E18);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_changing_max_limit_when_limit_is_used_updates_current_limit() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 100 * E18);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 50 * E18, 50 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 0);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 0);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_changing_partial_max_limit_updates_current_limit_when_used() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 10 * E18);
        setup.xerc20.burn(setup.user, 10 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 50 * E18, 50 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 40 * E18);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 40 * E18);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_changing_partial_max_limit_updates_current_limit_with_increase() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 10 * E18);
        setup.xerc20.burn(setup.user, 10 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 120 * E18, 120 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 110 * E18);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 110 * E18);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_current_limit_is_updated_with_time() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 100 * E18);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.owner), 100 * E18 / 2, E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(setup.owner), 100 * E18 / 2, E18 / 10,
        );

        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_current_limit_is_max_after_max_duration() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.mint(setup.user, 100 * E18);
        setup.xerc20.burn(setup.user, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 25 * HOUR);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 100 * E18);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 100 * E18);

        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_limit_is_same_if_unused() {
        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 100 * E18);
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 100 * E18);

        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_multiple_users_use_bridge() {
        let user_0 = starknet::contract_address_const::<'user_0'>();
        let user_1 = starknet::contract_address_const::<'user_1'>();
        let user_2 = starknet::contract_address_const::<'user_2'>();
        let user_3 = starknet::contract_address_const::<'user_3'>();
        let user_4 = starknet::contract_address_const::<'user_4'>();

        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);

        setup.xerc20.mint(user_0, 10 * E18);
        setup.xerc20.mint(user_1, 10 * E18);
        setup.xerc20.mint(user_2, 10 * E18);
        setup.xerc20.mint(user_3, 10 * E18);
        setup.xerc20.mint(user_4, 10 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 50 * E18);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.owner), 50 * E18 + 100 * E18 / 2, E18 / 10,
        );
        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_multiple_mints_and_burns() {
        let user_0 = starknet::contract_address_const::<'user_0'>();
        let user_1 = starknet::contract_address_const::<'user_1'>();
        let user_2 = starknet::contract_address_const::<'user_2'>();
        let user_3 = starknet::contract_address_const::<'user_3'>();
        let user_4 = starknet::contract_address_const::<'user_4'>();

        let setup = setup_base();

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, 100 * E18, 100 * E18);

        setup.xerc20.mint(user_0, 20 * E18);
        setup.xerc20.mint(user_1, 10 * E18);
        setup.xerc20.mint(user_2, 20 * E18);
        setup.xerc20.mint(user_3, 10 * E18);
        setup.xerc20.mint(user_4, 20 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.minting_current_limit_of(setup.owner) == 20 * E18);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        start_cheat_caller_address(setup.xerc20.contract_address, user_0);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, user_1);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, user_2);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, user_3);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, user_4);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.burn(user_0, 5 * E18);
        setup.xerc20.burn(user_1, 5 * E18);
        setup.xerc20.burn(user_2, 5 * E18);
        setup.xerc20.burn(user_3, 5 * E18);
        setup.xerc20.burn(user_4, 5 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 75 * E18);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.owner), 20 * E18 + 100 * E18 / 2, E18 / 10,
        );
        assert!(setup.xerc20.burning_current_limit_of(setup.owner) == 100 * E18);
        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_multiple_bridges_has_different_value() {
        let setup = setup_base();

        let owner_limit = 100 * E18;
        let user_limit = 50 * E18;

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, owner_limit, owner_limit);
        setup.xerc20.set_limits(setup.user, user_limit, user_limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        erc20_dispatcher.approve(setup.user, 100 * E18);

        setup.xerc20.mint(setup.user, 90 * E18);
        setup.xerc20.burn(setup.user, 90 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.mint(setup.owner, 40 * E18);
        setup.xerc20.burn(setup.owner, 40 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let minting_max_limit_of_owner = setup.xerc20.minting_max_limit_of(setup.owner);
        let minting_max_limit_of_user = setup.xerc20.minting_max_limit_of(setup.user);

        let minting_current_limit_of_owner = setup.xerc20.minting_current_limit_of(setup.owner);
        let minting_current_limit_of_user = setup.xerc20.minting_current_limit_of(setup.user);

        assert!(minting_max_limit_of_owner == owner_limit);
        assert!(minting_current_limit_of_owner == owner_limit - 90 * E18);

        assert!(minting_max_limit_of_user == user_limit);
        assert!(minting_current_limit_of_user == user_limit - 40 * E18);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.owner),
            owner_limit - 90 * E18 + owner_limit / 2,
            E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.user),
            user_limit - 40 * E18 + user_limit / 2,
            E18 / 10,
        );

        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(setup.owner),
            owner_limit - 90 * E18 + owner_limit / 2,
            E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(setup.user),
            user_limit - 40 * E18 + user_limit / 2,
            E18 / 10,
        );

        stop_cheat_block_timestamp_global();
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_multiple_bridges_burns_have_different_values() {
        let setup = setup_base();

        let owner_limit = 100 * E18;
        let user_limit = 50 * E18;

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        setup.xerc20.set_limits(setup.owner, owner_limit, owner_limit);
        setup.xerc20.set_limits(setup.user, user_limit, user_limit);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: setup.xerc20.contract_address,
        };

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        erc20_dispatcher.approve(setup.owner, 100 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.owner);
        erc20_dispatcher.approve(setup.user, 100 * E18);

        setup.xerc20.mint(setup.user, 90 * E18);
        setup.xerc20.burn(setup.user, 50 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
        setup.xerc20.mint(setup.owner, 40 * E18);
        setup.xerc20.burn(setup.owner, 25 * E18);
        stop_cheat_caller_address(setup.xerc20.contract_address);

        let burning_max_limit_of_owner = setup.xerc20.burning_max_limit_of(setup.owner);
        let burning_max_limit_of_user = setup.xerc20.burning_max_limit_of(setup.user);

        let burning_current_limit_of_owner = setup.xerc20.burning_current_limit_of(setup.owner);
        let burning_current_limit_of_user = setup.xerc20.burning_current_limit_of(setup.user);

        assert!(burning_max_limit_of_owner == owner_limit);
        assert!(burning_current_limit_of_owner == owner_limit - 50 * E18);

        assert!(burning_max_limit_of_user == user_limit);
        assert!(burning_current_limit_of_user == user_limit - 25 * E18);

        let current_timestamp = starknet::get_block_timestamp();
        start_cheat_block_timestamp_global(current_timestamp + 12 * HOUR);

        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.owner),
            owner_limit - 90 * E18 + owner_limit / 2,
            E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.minting_current_limit_of(setup.user),
            user_limit - 40 * E18 + user_limit / 2,
            E18 / 10,
        );

        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(setup.owner),
            owner_limit - 50 * E18 + owner_limit / 2,
            E18 / 10,
        );
        assert_approx_eq_rel(
            setup.xerc20.burning_current_limit_of(setup.user),
            user_limit - 25 * E18 + user_limit / 2,
            E18 / 10,
        );

        stop_cheat_block_timestamp_global();
    }
}

pub mod upgrade {
    use crate::e2e::common::setup_base;
    use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use snforge_std::{get_class_hash, start_cheat_caller_address, stop_cheat_caller_address};

    #[test]
    //#[fork("mainnet")]
    #[should_panic(expected: 'Caller is not the owner')]
    #[ignore]
    fn test_should_panic_when_upgrade_when_caller_not_owner() {
        let setup = setup_base();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        let new_class_hash = starknet::class_hash::class_hash_const::<'NEW_CLASS_HASH'>();
        start_cheat_caller_address(upgradeable_dispatcher.contract_address, setup.user);
        upgradeable_dispatcher.upgrade(new_class_hash);
        stop_cheat_caller_address(upgradeable_dispatcher.contract_address);
    }

    #[test]
    //#[fork("mainnet")]
    #[ignore]
    fn test_should_upgrade_implementation() {
        let setup = setup_base();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.xerc20.contract_address,
        };
        let new_class_hash = get_class_hash(setup.factory.contract_address);
        start_cheat_caller_address(upgradeable_dispatcher.contract_address, setup.owner);
        upgradeable_dispatcher.upgrade(new_class_hash);
        stop_cheat_caller_address(upgradeable_dispatcher.contract_address);
        assert!(
            get_class_hash(upgradeable_dispatcher.contract_address) == new_class_hash,
            "Class Hash does not match!",
        );
    }
}
