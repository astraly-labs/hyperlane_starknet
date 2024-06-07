use alexandria_bytes::{Bytes, BytesTrait, BytesIndex};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{HYPERLANE_ANNOUNCEMENT};
use hyperlane_starknet::interfaces::{
    IMockValidatorAnnounceDispatcher, IMockValidatorAnnounceDispatcherTrait
};
use hyperlane_starknet::tests::setup::setup_mock_validator_announce;
use starknet::{ContractAddress, contract_address_const, EthAddress};
pub const TEST_STARKNET_DOMAIN: u32 = 23448593;

#[test]
fn test_digest_computation() {
    let mailbox_address = contract_address_const::<
        0x0228c4f640b613dba2107cabf930564bbdb1b4e2d283ba1843b91e6327f09f8e
    >();

    let va = setup_mock_validator_announce(mailbox_address, TEST_STARKNET_DOMAIN);

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

    assert(
        digest == 68490098148397702232337918459455233145663417151157276422147736490102791983827,
        'Wrong digest'
    );
}
