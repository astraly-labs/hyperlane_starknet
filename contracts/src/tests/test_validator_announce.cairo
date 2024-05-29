use hyperlane_starknet::tests::setup::setup_mock_validator_announce;
use hyperlane_starknet::interfaces::{IMockValidatorAnnounceDispatcher, IMockValidatorAnnounceDispatcherTrait};
use starknet::{ContractAddress, contract_address_const, EthAddress};

pub const TEST_STARKNET_DOMAIN: u32 = 23448593;

#[test]
fn test_digest_computation() {
    let mailbox_address = contract_address_const::<0x0766b743bac733b88da5ccd5b2c05fa64505002bbaad9bec40f580668bb3110e>();
    
    let va = setup_mock_validator_announce(mailbox_address, TEST_STARKNET_DOMAIN);
    
    let mut _storage_location: Array<felt252> = array![
        180946006308525359965345158532346553211983108462325076142963585023296502126,
        90954189295124463684969781689350429239725285131197301894846683156275290468,
        437702665339219319625098735984930420
    ];

    let mut u256_storage_location: Array<u256> = array![];

    loop {
        match _storage_location.pop_front() {
            Option::Some(storage) => u256_storage_location.append(storage.into()),
            Option::None(()) => { break (); },
        }
    };

    let digest = va.get_announcement_digest(u256_storage_location);
    println!("digest: {:?}", digest);
    assert(digest == 40337292979712068912728133078015055981594797182684375963274381097875032981584, 'Wrong digest');
}
