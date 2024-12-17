use crate::{common::E18, e2e::common::{mint_dai, setup_base}};
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use snforge_std::{get_class_hash, start_cheat_caller_address, stop_cheat_caller_address};
use xerc20::lockbox::interface::XERC20LockboxABIDispatcherTrait;

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_lockbox() {
    let setup = setup_base();

    assert!(setup.lockbox.xerc20() == setup.xerc20.contract_address);
    assert!(setup.lockbox.erc20() == setup.dai.contract_address);
}

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_deposit() {
    let setup = setup_base();

    mint_dai(setup.user, 100 * E18);

    start_cheat_caller_address(setup.dai.contract_address, setup.user);
    setup.dai.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.dai.contract_address);

    start_cheat_caller_address(setup.lockbox.contract_address, setup.user);
    setup.lockbox.deposit(100 * E18);
    stop_cheat_caller_address(setup.lockbox.contract_address);

    assert!(
        ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address }
            .balance_of(setup.user) == 100
            * E18,
    );
    assert!(setup.dai.balance_of(setup.user) == 0);
    assert!(setup.dai.balance_of(setup.lockbox.contract_address) == 100 * E18);
}

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_deposit_to() {
    let setup = setup_base();

    mint_dai(setup.user, 100 * E18);

    start_cheat_caller_address(setup.dai.contract_address, setup.user);
    setup.dai.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.dai.contract_address);

    start_cheat_caller_address(setup.lockbox.contract_address, setup.user);
    setup.lockbox.deposit_to(setup.owner, 100 * E18);
    stop_cheat_caller_address(setup.lockbox.contract_address);

    assert!(
        ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address }
            .balance_of(setup.owner) == 100
            * E18,
    );
    assert!(setup.dai.balance_of(setup.user) == 0);
    assert!(setup.dai.balance_of(setup.lockbox.contract_address) == 100 * E18);
}

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_withdraw() {
    let setup = setup_base();

    mint_dai(setup.user, 100 * E18);

    start_cheat_caller_address(setup.dai.contract_address, setup.user);
    setup.dai.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.dai.contract_address);

    start_cheat_caller_address(setup.lockbox.contract_address, setup.user);
    setup.lockbox.deposit(100 * E18);
    let xerc20_erc20_dispatcher = ERC20ABIDispatcher {
        contract_address: setup.xerc20.contract_address,
    };
    start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
    xerc20_erc20_dispatcher.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.xerc20.contract_address);

    setup.lockbox.withdraw(100 * E18);
    stop_cheat_caller_address(setup.lockbox.contract_address);

    assert!(
        ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address }
            .balance_of(setup.user) == 0,
    );
    assert!(setup.dai.balance_of(setup.user) == 100 * E18);
    assert!(setup.dai.balance_of(setup.lockbox.contract_address) == 0);
}

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_withdraw_to() {
    let setup = setup_base();

    mint_dai(setup.user, 100 * E18);

    start_cheat_caller_address(setup.dai.contract_address, setup.user);
    setup.dai.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.dai.contract_address);

    start_cheat_caller_address(setup.lockbox.contract_address, setup.user);
    setup.lockbox.deposit(100 * E18);
    let xerc20_erc20_dispatcher = ERC20ABIDispatcher {
        contract_address: setup.xerc20.contract_address,
    };
    start_cheat_caller_address(setup.xerc20.contract_address, setup.user);
    xerc20_erc20_dispatcher.approve(setup.lockbox.contract_address, 100 * E18);
    stop_cheat_caller_address(setup.xerc20.contract_address);

    setup.lockbox.withdraw_to(setup.owner, 100 * E18);
    stop_cheat_caller_address(setup.lockbox.contract_address);

    assert!(
        ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address }
            .balance_of(setup.user) == 0,
    );
    assert!(setup.dai.balance_of(setup.owner) == 100 * E18);
    assert!(setup.dai.balance_of(setup.lockbox.contract_address) == 0);
}

#[test]
//#[fork("mainnet")]
#[should_panic(expected: 'Caller not XERC20 owner')]
#[ignore]
fn test_should_panic_when_upgrade_when_caller_not_xerc20_owner() {
    let setup = setup_base();
    let upgradeable_dispatcher = IUpgradeableDispatcher {
        contract_address: setup.lockbox.contract_address,
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
        contract_address: setup.lockbox.contract_address,
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
