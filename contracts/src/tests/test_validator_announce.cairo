use alexandria_bytes::{Bytes, BytesTrait, BytesIndex};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use hyperlane_starknet::contracts::isms::multisig::validator_announce::validator_announce;
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{HYPERLANE_ANNOUNCEMENT};
use hyperlane_starknet::interfaces::{
    IMockValidatorAnnounceDispatcher, IMockValidatorAnnounceDispatcherTrait,
    IValidatorAnnounceDispatcher, IValidatorAnnounceDispatcherTrait,
};
use hyperlane_starknet::tests::setup::{setup_mock_validator_announce, setup_validator_announce};
use snforge_std::cheatcodes::events::EventAssertions;
use starknet::{ContractAddress, contract_address_const, EthAddress};

pub const TEST_STARKNET_DOMAIN: u32 = 23448593;


#[test]
fn test_announce() {
    let (validator_announce, mut spy) = setup_validator_announce();
    let validator_address: EthAddress = 0x04171a0a7283cd5cdbf73dff367eb5a7f0e01d55
        .try_into()
        .unwrap();
    let mut _storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275291225,
        276191619276790668637754154763775604
    ];
    let mut signature = BytesTrait::new_empty();
    signature.append_u256(0x8e3c967ab6a3b9f93bb4242de0306510e688ea3db08d4e1590714aef8600f5f1);
    signature.append_u256(0x0f4866a1e36bc4134d9568af5d1d51ea7e51a291789f70799380d2d71f5dbf3d);
    signature.append_u8(0x1);
    let res = validator_announce.announce(validator_address, _storage_location.clone(), signature);
    assert_eq!(res, true);
    let expected_event = validator_announce::Event::ValidatorAnnouncement(
        validator_announce::ValidatorAnnouncement {
            validator: validator_address, storage_location: _storage_location.span()
        }
    );
    spy.assert_emitted(@array![(validator_announce.contract_address, expected_event),]);
    let validators = validator_announce.get_announced_validators();
    assert(validators == array![validator_address].span(), 'validator array mismatch');
    let storage_location = validator_announce.get_announced_storage_locations(validators);
    assert(*storage_location.at(0) == _storage_location.span(), 'wrong storage location');
}

#[test]
#[should_panic(expected: ('Wrong signer',))]
fn test_announce_fails_if_wrong_signer() {
    let (validator_announce, _) = setup_validator_announce();
    let validator_address: EthAddress = 'wrong_signer'.try_into().unwrap();
    let mut storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275291225,
        276191619276790668637754154763775604
    ];
    let mut signature = BytesTrait::new_empty();
    signature.append_u256(0x8e3c967ab6a3b9f93bb4242de0306510e688ea3db08d4e1590714aef8600f5f1);
    signature.append_u256(0x0f4866a1e36bc4134d9568af5d1d51ea7e51a291789f70799380d2d71f5dbf3d);
    signature.append_u8(0x1);
    validator_announce.announce(validator_address, storage_location.clone(), signature.clone());
    validator_announce.announce(validator_address, storage_location, signature);
}

#[test]
#[should_panic(expected: ('Announce already occured',))]
fn test_announce_fails_if_replay() {
    let (validator_announce, _) = setup_validator_announce();
    let validator_address: EthAddress = 0x04171a0a7283cd5cdbf73dff367eb5a7f0e01d55
        .try_into()
        .unwrap();
    let mut storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275291225,
        276191619276790668637754154763775604
    ];
    let mut signature = BytesTrait::new_empty();
    signature.append_u256(0x8e3c967ab6a3b9f93bb4242de0306510e688ea3db08d4e1590714aef8600f5f1);
    signature.append_u256(0x0f4866a1e36bc4134d9568af5d1d51ea7e51a291789f70799380d2d71f5dbf3d);
    signature.append_u8(0x1);
    validator_announce.announce(validator_address, storage_location.clone(), signature.clone());
    validator_announce.announce(validator_address, storage_location, signature);
}
#[test]
fn test_digest_computation() {
    let mailbox_address = contract_address_const::<
        0x0228c4f640b613dba2107cabf930564bbdb1b4e2d283ba1843b91e6327f09f8e
    >();

    let va = setup_mock_validator_announce(mailbox_address, TEST_STARKNET_DOMAIN);

    // file:///var/folders/kr/z3l_6qyn3znb6gbnddtvgsn40000gn/T/.tmpdY51LU/checkpoint
    let mut _storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275291225,
        276191619276790668637754154763775604
    ];

    let mut u256_storage_location: Array<u256> = array![];

    loop {
        match _storage_location.pop_front() {
            Option::Some(storage) => { u256_storage_location.append(storage.into()); },
            Option::None(()) => { break (); },
        }
    };
    let digest = va.get_announcement_digest(u256_storage_location);

    // digest printed in an e2e local test of the hyperlane validator
    assert(
        digest == 68490098148397702232337918459455233145663417151157276422147736490102791983827,
        'Wrong digest'
    );
}
