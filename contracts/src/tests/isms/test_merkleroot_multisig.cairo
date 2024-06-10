use alexandria_bytes::{Bytes, BytesTrait};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use core::array::ArrayTrait;
use core::array::SpanTrait;
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::contracts::libs::multisig::merkleroot_ism_metadata::merkleroot_ism_metadata::{
    MerkleRootIsmMetadata, MERKLE_PROOF_ITERATION
};
use hyperlane_starknet::contracts::mailbox::mailbox;
use hyperlane_starknet::interfaces::IMessageRecipientDispatcherTrait;
use hyperlane_starknet::interfaces::{
    IMailbox, IMailboxDispatcher, IMailboxDispatcherTrait, ModuleType,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IInterchainSecurityModule, IValidatorConfigurationDispatcher,
    IValidatorConfigurationDispatcherTrait,
};
use hyperlane_starknet::tests::setup::{
    setup, mock_setup, setup_merkleroot_multisig_ism, OWNER, NEW_OWNER, VALIDATOR_ADDRESS_1,
    VALIDATOR_ADDRESS_2, setup_validator_announce, get_merkle_message_and_signature, LOCAL_DOMAIN,
    DESTINATION_DOMAIN, RECIPIENT_ADDRESS, TEST_PROOF, build_merkle_metadata
};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::cheatcodes::events::EventAssertions;
use snforge_std::{start_prank, CheatTarget, stop_prank};
use starknet::eth_address::EthAddress;
use starknet::eth_signature::verify_eth_signature;
use starknet::secp256_trait::Signature;
use starknet::secp256_trait::signature_from_vrs;

#[test]
fn test_set_validators() {
    let new_validators = array![VALIDATOR_ADDRESS_1(), VALIDATOR_ADDRESS_2()].span();
    let (_, validators) = setup_merkleroot_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    validators.set_validators(new_validators);
    let validators_span = validators.get_validators();
    assert(validators_span == new_validators, 'wrong validator address def');
}


#[test]
fn test_set_threshold() {
    let new_threshold = 3;
    let (_, validators) = setup_merkleroot_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    validators.set_threshold(new_threshold);
    assert(validators.get_threshold() == new_threshold, 'wrong validator threshold');
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_validators_fails_if_caller_not_owner() {
    let new_validators = array![VALIDATOR_ADDRESS_1()].span();
    let (_, validators) = setup_merkleroot_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    validators.set_validators(new_validators);
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_validators_fails_if_null_validator() {
    let new_validators = array![VALIDATOR_ADDRESS_1(), 0.try_into().unwrap()].span();
    let (_, validators) = setup_merkleroot_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    validators.set_validators(new_validators);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_threshold_fails_if_caller_not_owner() {
    let new_threshold = 3;
    let (_, validators) = setup_merkleroot_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    validators.set_threshold(new_threshold);
}


#[test]
fn test_merkleroot_ism_metadata() {
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id
    );
    let proof = TEST_PROOF();
    let (_, _, signatures) = get_merkle_message_and_signature();
    assert(
        MerkleRootIsmMetadata::origin_merkle_tree_hook(metadata.clone()) == origin_merkle_tree_hook,
        'wrong merkle tree hook'
    );
    assert(
        MerkleRootIsmMetadata::message_index(metadata.clone()) == message_index,
        'wrong message_index'
    );
    assert(
        MerkleRootIsmMetadata::signed_index(metadata.clone()) == signed_index, 'wrong signed index'
    );
    assert(
        MerkleRootIsmMetadata::signed_message_id(metadata.clone()) == signed_message_id,
        'wrong signed_message_id'
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
                metadata.clone(), cur_idx
            ) == (y_parity, *signatures.at(cur_idx).r, *signatures.at(cur_idx).s),
            'wrong signature '
        );
        cur_idx += 1;
    }
}


#[test]
fn test_merkle_root_multisig_module_type() {
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism();
    assert(
        merkleroot_ism
            .module_type() == ModuleType::MERKLE_ROOT_MULTISIG(merkleroot_ism.contract_address),
        'Wrong module type'
    );
}


#[test]
fn test_merkle_root_multisig_verify_with_4_valid_signatures() {
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: RECIPIENT_ADDRESS(),
        body: message_body.clone()
    };
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let (merkleroot_ism, merkleroot_validator_configuration) = setup_merkleroot_multisig_ism();
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id
    );
    let ownable = IOwnableDispatcher {
        contract_address: merkleroot_validator_configuration.contract_address
    };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_configuration.set_validators(validators_address.span());
    merkleroot_validator_configuration.set_threshold(4);
    assert(merkleroot_ism.verify(metadata, message) == true, 'verification failed');
}


#[test]
#[should_panic(expected: ('No match for given signature',))]
fn test_merkle_root_multisig_verify_with_insufficient_valid_signatures() {
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: RECIPIENT_ADDRESS(),
        body: message_body.clone()
    };
    let (merkleroot_ism, merkleroot_validator_config) = setup_merkleroot_multisig_ism();
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let origin_merkle_tree_hook: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index: u32 = 1;
    let signed_index: u32 = 2;
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let mut metadata = build_merkle_metadata(
        origin_merkle_tree_hook, message_index, signed_index, signed_message_id
    );
    metadata.update_at(1100, 0);
    let ownable = IOwnableDispatcher { contract_address: merkleroot_ism.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_config.set_validators(validators_address.span());
    merkleroot_validator_config.set_threshold(4);
    assert(merkleroot_ism.verify(metadata, message) == true, 'verification failed');
}


#[test]
#[should_panic(expected: ('Empty metadata',))]
fn test_merkle_root_multisig_verify_with_empty_metadata() {
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000
    ];
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: RECIPIENT_ADDRESS(),
        body: message_body.clone()
    };
    let (merkle_root_ism, merkleroot_validator_config) = setup_merkleroot_multisig_ism();
    let (_, validators_address, _) = get_merkle_message_and_signature();
    let ownable = IOwnableDispatcher { contract_address: merkle_root_ism.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_config.set_validators(validators_address.span());
    merkleroot_validator_config.set_threshold(4);
    let bytes_metadata = BytesTrait::new_empty();
    assert(merkle_root_ism.verify(bytes_metadata, message) == true, 'verification failed');
}

