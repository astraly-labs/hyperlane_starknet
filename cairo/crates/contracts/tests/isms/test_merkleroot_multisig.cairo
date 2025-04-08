use alexandria_bytes::BytesTrait;
use contracts::interfaces::{
    IInterchainSecurityModuleDispatcherTrait, IValidatorConfigurationDispatcherTrait, ModuleType,
};
use contracts::libs::message::{HYPERLANE_VERSION, Message};
use contracts::libs::multisig::merkleroot_ism_metadata::merkleroot_ism_metadata::MerkleRootIsmMetadata;
use contracts::utils::utils::U256TryIntoContractAddress;
use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::option::OptionTrait;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{CheatSpan, cheat_caller_address};
use super::super::setup::{
    DESTINATION_DOMAIN, LOCAL_DOMAIN, OWNER, TEST_PROOF, VALIDATOR_ADDRESS_1, VALIDATOR_ADDRESS_2,
    VALID_OWNER, VALID_RECIPIENT, build_fake_merkle_metadata, build_merkle_metadata,
    get_merkle_message_and_signature, setup_merkleroot_multisig_ism,
};


#[test]
fn test_set_validators() {
    let threshold = 2;
    let new_validators: Array<felt252> = array![
        VALIDATOR_ADDRESS_1().into(), VALIDATOR_ADDRESS_2().into(),
    ];
    let (_, validators) = setup_merkleroot_multisig_ism(new_validators.span(), threshold);
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    let validators_span = validators.get_validators();
    assert_eq!(*validators_span.at(0).into(), (*new_validators.at(0)).try_into().unwrap());
    assert_eq!(*validators_span.at(1).into(), (*new_validators.at(1)).try_into().unwrap());
}


#[test]
fn test_set_threshold() {
    let threshold = 3;
    let (_, validators) = setup_merkleroot_multisig_ism(array!['validator_1'].span(), threshold);
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    assert(validators.get_threshold() == threshold, 'wrong validator threshold');
}


#[test]
#[should_panic]
fn test_set_validators_fails_if_null_validator() {
    let threshold = 2;
    let new_validators = array![VALIDATOR_ADDRESS_1().into(), 0].span();
    setup_merkleroot_multisig_ism(new_validators, threshold);
}


#[test]
fn test_merkleroot_ism_metadata() {
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id,
    );
    let proof = TEST_PROOF();
    let (_, _, signatures) = get_merkle_message_and_signature();
    assert(
        MerkleRootIsmMetadata::origin_merkle_tree_hook(metadata.clone()) == origin_merkle_tree_hook,
        'wrong merkle tree hook',
    );
    assert(
        MerkleRootIsmMetadata::message_index(metadata.clone()) == message_index,
        'wrong message_index',
    );
    assert(
        MerkleRootIsmMetadata::signed_index(metadata.clone()) == signed_index, 'wrong signed index',
    );
    assert(
        MerkleRootIsmMetadata::signed_message_id(metadata.clone()) == signed_message_id,
        'wrong signed_message_id',
    );
    assert(MerkleRootIsmMetadata::proof(metadata.clone()) == proof, 'wrong proof');
    let y_parity = 0x01;
    let mut cur_idx = 0;
    loop {
        if (cur_idx == signatures.len()) {
            break ();
        }
        assert(
            MerkleRootIsmMetadata::signature_at(
                metadata.clone(), cur_idx,
            ) == (y_parity, *signatures.at(cur_idx).r, *signatures.at(cur_idx).s),
            'wrong signature ',
        );
        cur_idx += 1;
    }
}


#[test]
fn test_merkle_root_multisig_module_type() {
    let threshold = 2;
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism(
        array!['validator_1'].span(), threshold,
    );
    assert(
        merkleroot_ism
            .module_type() == ModuleType::MERKLE_ROOT_MULTISIG(merkleroot_ism.contract_address),
        'Wrong module type',
    );
}


#[test]
fn test_merkle_root_multisig_verify_with_4_valid_signatures() {
    let threshold = 4;
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: VALID_OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: VALID_RECIPIENT(),
        body: message_body.clone(),
    };
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism(validators_address.span(), threshold);
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id,
    );
    assert(merkleroot_ism.verify(metadata, message) == true, 'verification failed');
}


#[test]
#[should_panic(expected: ('No match for given signature',))]
fn test_merkle_root_multisig_verify_with_insufficient_valid_signatures() {
    let threshold = 4;
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: VALID_OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: VALID_RECIPIENT(),
        body: message_body.clone(),
    };
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism(validators_address.span(), threshold);
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let mut metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id,
    );
    metadata.update_at(1100, 0);
    assert(merkleroot_ism.verify(metadata, message) == true, 'verification failed');
}


#[test]
#[should_panic(expected: ('Empty metadata',))]
fn test_merkle_root_multisig_verify_with_empty_metadata() {
    let threshold = 4;
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: VALID_OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: VALID_RECIPIENT(),
        body: message_body.clone(),
    };
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let (merkle_root_ism, _) = setup_merkleroot_multisig_ism(validators_address.span(), threshold);
    let bytes_metadata = BytesTrait::new_empty();
    assert(merkle_root_ism.verify(bytes_metadata, message) == true, 'verification failed');
}


#[test]
#[should_panic(expected: ('No match for given signature',))]
fn test_merkle_root_multisig_verify_with_4_valid_signatures_fails_if_duplicate_signatures() {
    let threshold = 4;

    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: VALID_OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: VALID_RECIPIENT(),
        body: message_body.clone(),
    };
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism(validators_address.span(), threshold);
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let metadata = build_fake_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id,
    );
    assert(merkleroot_ism.verify(metadata, message) == true, 'verification failed');
}
