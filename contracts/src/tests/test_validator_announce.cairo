use hyperlane_starknet::interfaces::{
    IMockValidatorAnnounceDispatcher, IMockValidatorAnnounceDispatcherTrait
};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use hyperlane_starknet::tests::setup::setup_mock_validator_announce;
use starknet::{ContractAddress, contract_address_const, EthAddress};
use alexandria_bytes::{Bytes, BytesTrait, BytesIndex};
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{
    HYPERLANE_ANNOUNCEMENT
};
pub const TEST_STARKNET_DOMAIN: u32 = 23448593;

#[test]
fn test_digest_computation() {
    let mailbox_address = contract_address_const::<
        0x0766b743bac733b88da5ccd5b2c05fa64505002bbaad9bec40f580668bb3110e
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
    println!("digest: {:?}", digest);

    // Bytes version
    let felt252_mailbox_address : felt252= mailbox_address.into();
    let u256_mailbox_address: u256 = felt252_mailbox_address.into();
    let u256_hyperlane_ann : u256 = HYPERLANE_ANNOUNCEMENT.into();

    let bytes_arr : Array::<u128> = array![TEST_STARKNET_DOMAIN.into(),u256_mailbox_address.high, u256_mailbox_address.low,u256_hyperlane_ann.high, u256_hyperlane_ann.low];
    let first_bytes = BytesTrait::new(80, bytes_arr.clone());
    println!("bytes domain hash digest: {:?}", first_bytes.keccak());

    let bytes: Bytes = BytesTrait::new(496, bytes_arr.concat(@u128_storage_location));
    println!("bytes digest: {:?}", bytes.keccak());


    assert(
        digest == 40337292979712068912728133078015055981594797182684375963274381097875032981584,
        'Wrong digest'
    );
}

#[test]
#[available_gas(20000000)]
fn test_bytes_keccak() {
    // Calculating keccak by Python
    // from Crypto.Hash import keccak
    // k = keccak.new(digest_bits=256)
    // k.update(bytes.fromhex(''))
    // print(k.hexdigest())

    // empty
    let bytes = BytesTrait::new_empty();
    let hash: u256 = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    let res = bytes.keccak();

    
    assert_eq!(res, hash, "bytes_keccak_0");

    // u256{low: 1, high: 0}
    let mut array = array![];
    array.append(0);
    array.append(1);
    let bytes: Bytes = BytesTrait::new(32, array);
    let res = bytes.keccak();
    let hash: u256 = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6;
    assert_eq!(res, hash, "bytes_keccak_1");

    // test_bytes_append bytes
    let mut array = array![];
    array.append(0x10111213141516171810111213141516);
    array.append(0x17180101020102030400000001000003);
    array.append(0x04050607080000000000000010111213);
    array.append(0x14151617180000000000000001020304);
    array.append(0x05060708090000000000000000000102);
    array.append(0x0304050607015401855d7796176b05d1);
    array.append(0x60196ff92381eb7910f5446c2e0e04e1);
    array.append(0x3db2194a4f0000000000000000000000);

    let bytes: Bytes = BytesTrait::new(117, array);

    let hash: u256 = 0xcb1bcb5098bb2f588b82ea341e3b1148b7d1eeea2552d624b30f4240b5b85995;
    let res = bytes.keccak();
    assert_eq!(res, hash, "bytes_keccak_2");
}