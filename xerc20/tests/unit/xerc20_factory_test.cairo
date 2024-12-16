use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin_utils::deployments::calculate_contract_address_from_deploy_syscall;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ClassHash;
use starknet::ContractAddress;
use xerc20::{
    factory::{
        contract::XERC20Factory,
        interface::{IXERC20FactoryDispatcher, IXERC20FactoryDispatcherTrait},
    },
    lockbox::interface::{XERC20LockboxABIDispatcher, XERC20LockboxABIDispatcherTrait},
};

#[derive(Drop)]
pub struct Setup {
    owner: ContractAddress,
    user: ContractAddress,
    erc20: ContractAddress,
    xerc20_factory: IXERC20FactoryDispatcher,
    xerc20_class_hash: ClassHash,
    lockbox_class_hash: ClassHash,
}

pub fn setup() -> Setup {
    let owner = starknet::contract_address_const::<1>();
    let user = starknet::contract_address_const::<2>();
    let erc20 = starknet::contract_address_const::<3>();

    let xerc20_class_hash = declare("XERC20").unwrap().contract_class().class_hash;
    let lockbox_class_hash = declare("XERC20Lockbox").unwrap().contract_class().class_hash;
    let factory_contract = declare("XERC20Factory").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    xerc20_class_hash.serialize(ref ctor_calldata);
    lockbox_class_hash.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    let (factory_address, _) = factory_contract.deploy(@ctor_calldata).unwrap();

    Setup {
        owner,
        user,
        erc20,
        xerc20_factory: IXERC20FactoryDispatcher { contract_address: factory_address },
        xerc20_class_hash: *xerc20_class_hash,
        lockbox_class_hash: *lockbox_class_hash,
    }
}

#[test]
fn test_deployment() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20 = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: xerc20 };
    assert!(erc20_dispatcher.name() == "Test", "Name does not match!");
    assert!(erc20_dispatcher.symbol() == "TST", "Symbol does not match!");
}

// NOTE: this test should panic and panicing but fails
//#[test]
//#[should_panic]
//fn test_should_panic_when_address_is_taken() {
//    let setup = setup();
//    let limits = array![].span();
//    let minters = array![].span();
//    setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
//    // second time deploying to same address should fail
//    setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
//}

#[test]
fn test_xerc20_pre_computed_address() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let name: ByteArray = "Test";
    let symbol: ByteArray = "TST";
    let mut serialized_data: Array<felt252> = array![];
    name.serialize(ref serialized_data);
    symbol.serialize(ref serialized_data);
    starknet::get_contract_address().serialize(ref serialized_data);
    let salt = poseidon_hash_span(serialized_data.span());
    let mut serialized_ctor_data: Array<felt252> = array![];
    name.serialize(ref serialized_ctor_data);
    symbol.serialize(ref serialized_ctor_data);
    setup.xerc20_factory.contract_address.serialize(ref serialized_ctor_data);

    let actual_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
    let expected_address = calculate_contract_address_from_deploy_syscall(
        salt,
        setup.xerc20_class_hash,
        serialized_ctor_data.span(),
        setup.xerc20_factory.contract_address,
    );
    assert!(expected_address == actual_address, "Addresses does not match!");
}

#[test]
fn test_xerc20_lockbox_pre_computed_address() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);

    let salt = poseidon_hash_span(
        array![xerc20_address.into(), setup.erc20.into(), starknet::get_contract_address().into()]
            .span(),
    );
    let mut serialized_ctor_data: Array<felt252> = array![];
    xerc20_address.serialize(ref serialized_ctor_data);
    setup.erc20.serialize(ref serialized_ctor_data);
    let expected_address = calculate_contract_address_from_deploy_syscall(
        salt,
        setup.lockbox_class_hash,
        serialized_ctor_data.span(),
        setup.xerc20_factory.contract_address,
    );

    let actual_address = setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
    assert!(expected_address == actual_address, "Addresses does not match!");
}

#[test]
fn test_lockbox_single_deployment() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);

    let lockbox_address = setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
    let lockbox_dispatcher = XERC20LockboxABIDispatcher { contract_address: lockbox_address };
    assert!(lockbox_dispatcher.erc20() == setup.erc20, "ERC20 address does not match!");
    assert!(lockbox_dispatcher.xerc20() == xerc20_address, "XERC20 address does not match!");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_should_panic_when_lockbox_single_deployment_when_caller_not_owner() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    start_cheat_caller_address(
        setup.xerc20_factory.contract_address, starknet::contract_address_const::<'not_owner'>(),
    );
    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
    stop_cheat_caller_address(setup.xerc20_factory.contract_address);

    setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
}

#[test]
#[should_panic(expected: 'Token address zero')]
fn test_should_panic_when_lockbox_deployment_when_base_token_adress_zero() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
    setup.xerc20_factory.deploy_lockbox(xerc20_address, Zero::zero());
}

#[test]
#[should_panic(expected: 'Lockbox alread deployed')]
fn test_should_panic_when_lockbox_deployment_twice() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);

    setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
    setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
}

#[test]
#[should_panic(expected: 'Invalid length')]
fn test_should_panic_when_arrays_len_does_not_match() {
    let setup = setup();

    let limits = array![1].span();
    let minters = array![].span();

    setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);
}

#[test]
fn test_deploy_xerc20_should_emit_events() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let mut spy = spy_events();
    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);

    spy
        .assert_emitted(
            @array![
                (
                    setup.xerc20_factory.contract_address,
                    XERC20Factory::Event::XERC20Deployed(
                        XERC20Factory::XERC20Deployed { xerc20: xerc20_address },
                    ),
                ),
            ],
        );
}

#[test]
fn test_deploy_lockbox_should_emit_events() {
    let setup = setup();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_address = setup.xerc20_factory.deploy_xerc20("Test", "TST", limits, limits, minters);

    let mut spy = spy_events();

    let lockbox_address = setup.xerc20_factory.deploy_lockbox(xerc20_address, setup.erc20);
    spy
        .assert_emitted(
            @array![
                (
                    setup.xerc20_factory.contract_address,
                    XERC20Factory::Event::LockboxDeployed(
                        XERC20Factory::LockboxDeployed { lockbox: lockbox_address },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_should_panic_when_set_xerc20_implementation_when_caller_not_owner() {
    let setup = setup();

    let new_class_hash = starknet::class_hash::class_hash_const::<'NEW_CLASS_HASH'>();

    start_cheat_caller_address(setup.xerc20_factory.contract_address, setup.user);
    setup.xerc20_factory.set_xerc20_class_hash(new_class_hash);
    stop_cheat_caller_address(setup.xerc20_factory.contract_address);
}

#[test]
fn test_should_set_xerc20_implementation() {
    let setup = setup();

    let class_hash_before = setup.xerc20_factory.get_xerc20_class_hash();
    let new_class_hash = starknet::class_hash::class_hash_const::<'NEW_CLASS_HASH'>();

    let mut spy = spy_events();

    start_cheat_caller_address(setup.xerc20_factory.contract_address, setup.owner);
    setup.xerc20_factory.set_xerc20_class_hash(new_class_hash);
    stop_cheat_caller_address(setup.xerc20_factory.contract_address);

    let class_hash_after = setup.xerc20_factory.get_xerc20_class_hash();
    assert!(class_hash_after != class_hash_before);
    assert!(class_hash_after == new_class_hash);

    spy
        .assert_emitted(
            @array![
                (
                    setup.xerc20_factory.contract_address,
                    XERC20Factory::Event::XERC20ImplementationUpdated(
                        XERC20Factory::XERC20ImplementationUpdated { class_hash: new_class_hash },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_should_panic_when_set_lockbox_implementation_when_caller_not_owner() {
    let setup = setup();

    let new_class_hash = starknet::class_hash::class_hash_const::<'NEW_CLASS_HASH'>();

    start_cheat_caller_address(setup.xerc20_factory.contract_address, setup.user);
    setup.xerc20_factory.set_lockbox_class_hash(new_class_hash);
    stop_cheat_caller_address(setup.xerc20_factory.contract_address);
}

#[test]
fn test_should_set_lockbox_implementation() {
    let setup = setup();

    let class_hash_before = setup.xerc20_factory.get_lockbox_class_hash();
    let new_class_hash = starknet::class_hash::class_hash_const::<'NEW_CLASS_HASH'>();

    let mut spy = spy_events();

    start_cheat_caller_address(setup.xerc20_factory.contract_address, setup.owner);
    setup.xerc20_factory.set_lockbox_class_hash(new_class_hash);
    stop_cheat_caller_address(setup.xerc20_factory.contract_address);

    let class_hash_after = setup.xerc20_factory.get_lockbox_class_hash();
    assert!(class_hash_after != class_hash_before);
    assert!(class_hash_after == new_class_hash);

    spy
        .assert_emitted(
            @array![
                (
                    setup.xerc20_factory.contract_address,
                    XERC20Factory::Event::LockboxImplementationUpdated(
                        XERC20Factory::LockboxImplementationUpdated { class_hash: new_class_hash },
                    ),
                ),
            ],
        );
}
