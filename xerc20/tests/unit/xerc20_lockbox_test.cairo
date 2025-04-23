use openzeppelin_token::erc20::interface::ERC20ABIDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use xerc20::{lockbox::interface::IXERC20LockboxDispatcher, xerc20::interface::IXERC20Dispatcher};

#[derive(Drop)]
pub struct Setup {
    owner: ContractAddress,
    user: ContractAddress,
    minter: ContractAddress,
    xerc20: IXERC20Dispatcher,
    erc20: ERC20ABIDispatcher,
    lockbox: IXERC20LockboxDispatcher,
}

pub fn setup() -> Setup {
    let owner = starknet::contract_address_const::<1>();
    let user = starknet::contract_address_const::<2>();
    let minter = starknet::contract_address_const::<3>();

    let mock_erc20_contract = declare("MockErc20").unwrap().contract_class();
    let (erc20_address, _) = mock_erc20_contract.deploy(@array![]).unwrap();
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: erc20_address };

    let xerc20_contract = declare("MockXERC20").unwrap().contract_class();
    let (xerc20_address, _) = xerc20_contract.deploy(@array![]).unwrap();
    let xerc20_dispatcher = IXERC20Dispatcher { contract_address: xerc20_address };

    let xerc20_lockbox_contract = declare("XERC20Lockbox").unwrap().contract_class();
    let (xerc20_lockbox_address, _) = xerc20_lockbox_contract
        .deploy(@array![xerc20_address.into(), erc20_address.into()])
        .unwrap();

    Setup {
        owner,
        user,
        minter,
        xerc20: xerc20_dispatcher,
        erc20: erc20_dispatcher,
        lockbox: IXERC20LockboxDispatcher { contract_address: xerc20_lockbox_address },
    }
}

mod unit_deposit {
    use core::num::traits::Bounded;
    use core::num::traits::Zero;
    use crate::common::bound;
    use openzeppelin_token::erc20::erc20::ERC20Component;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;
    use xerc20::lockbox::{
        component::XERC20LockboxComponent, interface::IXERC20LockboxDispatcherTrait,
    };

    #[test]
    #[fuzzer]
    fn test_deposit(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.deposit(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.erc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.owner,
                                to: setup.lockbox.contract_address,
                                value: amount,
                            },
                        ),
                    ),
                    (
                        setup.xerc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: Zero::zero(), to: setup.owner, value: amount,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'ERC20 transfer_from failed')]
    fn test_deposit_should_panic_when_transfer_from_returns_false(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);
        mock_call(setup.erc20.contract_address, selector!("transfer_from"), false, 1);
        mock_call(setup.xerc20.contract_address, selector!("mint"), (), 1);

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.deposit(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_deposit_to(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.deposit_to(setup.user, amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.erc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.owner,
                                to: setup.lockbox.contract_address,
                                value: amount,
                            },
                        ),
                    ),
                    (
                        setup.xerc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: Zero::zero(), to: setup.user, value: amount,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'ERC20 transfer_from failed')]
    fn test_deposit_to_should_panic_when_transfer_from_returns_false(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);
        mock_call(setup.erc20.contract_address, selector!("transfer_from"), false, 1);
        mock_call(setup.xerc20.contract_address, selector!("mint"), (), 1);

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.deposit_to(setup.user, amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_deposit_emits_event(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);
        mock_call(setup.erc20.contract_address, selector!("transfer_from"), true, 1);
        mock_call(setup.xerc20.contract_address, selector!("mint"), (), 1);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.deposit(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);
        spy
            .assert_emitted(
                @array![
                    (
                        setup.lockbox.contract_address,
                        XERC20LockboxComponent::Event::Deposit(
                            XERC20LockboxComponent::Deposit { sender: setup.owner, amount },
                        ),
                    ),
                ],
            );
    }
}


pub mod unit_withdraw {
    use core::num::traits::{Bounded, Zero};
    use crate::common::bound;
    use openzeppelin_token::erc20::erc20::ERC20Component;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;
    use xerc20::lockbox::{
        component::XERC20LockboxComponent, interface::IXERC20LockboxDispatcherTrait,
    };

    #[test]
    #[fuzzer]
    fn test_withdraw(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.withdraw(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.erc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.lockbox.contract_address,
                                to: setup.owner,
                                value: amount,
                            },
                        ),
                    ),
                    (
                        setup.xerc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.owner, to: Zero::zero(), value: amount,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'ERC20 transfer failed')]
    fn test_withdraw_should_panic_when_transfer_returns_false(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);
        mock_call(setup.erc20.contract_address, selector!("transfer"), false, 1);
        mock_call(setup.xerc20.contract_address, selector!("burn"), (), 1);

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.withdraw(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_withdraw_to(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.withdraw_to(setup.user, amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.erc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.lockbox.contract_address, to: setup.user, value: amount,
                            },
                        ),
                    ),
                    (
                        setup.xerc20.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: setup.owner, to: Zero::zero(), value: amount,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[fuzzer]
    #[should_panic(expected: 'ERC20 transfer failed')]
    fn test_withdraw_to_should_panic_when_transfer_returns_false(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);
        mock_call(setup.erc20.contract_address, selector!("transfer"), false, 1);
        mock_call(setup.xerc20.contract_address, selector!("burn"), (), 1);

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.withdraw_to(setup.user, amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);
    }

    #[test]
    #[fuzzer]
    fn test_withdraw_emit_events(mut amount: u256) {
        let setup = setup();

        amount = bound(amount, 1, Bounded::MAX);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.lockbox.contract_address, setup.owner);
        setup.lockbox.withdraw(amount);
        stop_cheat_caller_address(setup.lockbox.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.lockbox.contract_address,
                        XERC20LockboxComponent::Event::Withdraw(
                            XERC20LockboxComponent::Withdraw { sender: setup.owner, amount },
                        ),
                    ),
                ],
            );
    }
}
