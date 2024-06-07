use alexandria_bytes::{Bytes, BytesTrait, BytesIndex};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{HYPERLANE_ANNOUNCEMENT};
use hyperlane_starknet::interfaces::{
    IMockValidatorAnnounceDispatcher, IMockValidatorAnnounceDispatcherTrait
};
use hyperlane_starknet::tests::setup::setup_mock_validator_announce;
use starknet::{ContractAddress, contract_address_const, EthAddress};
pub const TEST_STARKNET_DOMAIN: u32 = 23448594;

#[test]
#[ignore]
fn test_digest_computation() {
    let mailbox_address = contract_address_const::<
        0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a
    >();

    let va = setup_mock_validator_announce(mailbox_address, TEST_STARKNET_DOMAIN);

    let mut _storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275290468,
        437702665339219319625098735984930420
    ];

    let mut u256_storage_location: Array<u256> = array![];
    let mut u128_storage_location: Array<u128> = array![];

    loop {
        match _storage_location.pop_front() {
            Option::Some(storage) => {
                let u256_storage: u256 = storage.into();
                u256_storage_location.append(storage.into());
                u128_storage_location.append(u256_storage.high);
                u128_storage_location.append(u256_storage.low);
            },
            Option::None(()) => { break (); },
        }
    };
    let digest = va.get_announcement_digest(u256_storage_location);

    assert(
        digest == 40337292979712068912728133078015055981594797182684375963274381097875032981584,
        'Wrong digest'
    );
}
