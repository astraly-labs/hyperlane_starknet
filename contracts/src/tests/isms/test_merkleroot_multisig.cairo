use alexandria_bytes::{Bytes, BytesTrait};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use core::array::ArrayTrait;
use core::array::SpanTrait;
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::contracts::libs::multisig::merkleroot_ism_metadata::merkleroot_ism_metadata::{MerkleRootIsmMetadata,MERKLE_PROOF_ITERATION};
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
    VALIDATOR_ADDRESS_2, setup_validator_announce, get_message_and_signature, LOCAL_DOMAIN,
    DESTINATION_DOMAIN, RECIPIENT_ADDRESS
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
#[ignore]
fn test_merkleroot_ism_metadata() {
    let origin_merkle_tree_hook : u256= 'origin_merkle_tree_hook'.try_into().unwrap();
    let message_index : u32= 'm_index'.try_into().unwrap(); 
    let signed_index : u32 = 's_index'.try_into().unwrap();
    let signed_message_id: u256 = 'signed_message_id'.try_into().unwrap();
    let proof = array![
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000, 
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000, 
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
    ].span();
    let signature_1 = array![
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000
    ];
    let signature_2 = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
        0x02000000000000000000000000000000
    ];
    let signature_3 = array![
        0x01020304050607080910111213141516,
        0x13092450000011115450564500700000,
        0x01020304050607080910000000000000,
        0x01020304050607080910111213141516,
        0x02000000000000000000000000000000
    ];
    let signature = signature_1.concat(@signature_2).concat(@signature_3);
    let signature_1_v = 0x3;
    let signature_2_v = 0x2;
    let signature_3_v = 0x2;
    let mut metadata = BytesTrait::new_empty();
    metadata.append_u256(origin_merkle_tree_hook);
    metadata.append_u32(message_index);
    metadata.append_u32(signed_index);
    let mut cur_idx = 0;
    loop {
        if (cur_idx == MERKLE_PROOF_ITERATION){
            break();
        }
        metadata.append_u128(*proof.at(cur_idx));
        cur_idx +=1;

    }; 
    cur_idx =0;
    loop {
        if (cur_idx == signature.len()){
            break();
        }
        metadata.append_u128(*proof.at(cur_idx));
        cur_idx +=1;
    };
    let bytes_metadata = BytesTrait::new(496, metadata);
    assert(
        MerkleRootIsmMetadata::origin_merkle_tree_hook(
            bytes_metadata.clone()
        ) == u256 { low: *origin_merkle_tree_hook.at(1), high: *origin_merkle_tree_hook.at(0) },
        'wrong merkle tree hook'
    );
    assert(
        MerkleRootIsmMetadata::root(
            bytes_metadata.clone()
        ) == u256 { low: *root.at(1), high: *root.at(0) },
        'wrong root'
    );
    assert(MerkleRootIsmMetadata::index(bytes_metadata.clone()) == index_u32, 'wrong index');
    assert(
        MerkleRootIsmMetadata::signature_at(
            bytes_metadata.clone(), 0
        ) == (
            signature_1_v,
            u256 { low: *signature_1.at(1), high: *signature_1.at(0) },
            u256 { low: *signature_1.at(3), high: *signature_1.at(2) }
        ),
        'wrong signature 1'
    );
    assert(
        MerkleRootIsmMetadata::signature_at(
            bytes_metadata.clone(), 1
        ) == (
            signature_2_v,
            u256 { low: *signature_2.at(1), high: *signature_2.at(0) },
            u256 { low: *signature_2.at(3), high: *signature_2.at(2) }
        ),
        'wrong signature 2'
    );
    assert(
        MerkleRootIsmMetadata::signature_at(
            bytes_metadata.clone(), 2
        ) == (
            signature_3_v,
            u256 { low: *signature_3.at(1), high: *signature_3.at(0) },
            u256 { low: *signature_3.at(3), high: *signature_3.at(2) }
        ),
        'wrong signature 3'
    );
}


#[test]
fn test_merkle_root_multisig_module_type() {
    let (merkleroot_ism, _) = setup_merkleroot_multisig_ism();
    assert(
        merkleroot_ism.module_type() == ModuleType::MERKLE_ROOT_MULTISIG(merkleroot_ism.contract_address),
        'Wrong module type'
    );
}


#[test]
#[ignore]
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
    let (merkleroot_ism, merkleroot_validator_configuration) = setup_merkleroot_multisig_ism();
    let (_, validators_address, signatures) = get_message_and_signature();
    let y_parity = 0x01000000000000000000000000000000; // parity set to false
    let metadata = array![
        0x01020304050607080910111213141516,
        0x16151413121110090807060504030201,
        0x01020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x00000010000000000000000000000000,
        *signatures.at(0).r.high,
        *signatures.at(0).r.low,
        *signatures.at(0).s.high,
        *signatures.at(0).s.low,
        y_parity,
        *signatures.at(1).r.high,
        *signatures.at(1).r.low,
        *signatures.at(1).s.high,
        *signatures.at(1).s.low,
        y_parity,
        *signatures.at(2).r.high,
        *signatures.at(2).r.low,
        *signatures.at(2).s.high,
        *signatures.at(2).s.low,
        y_parity,
        *signatures.at(3).r.high,
        *signatures.at(3).r.low,
        *signatures.at(3).s.high,
        *signatures.at(3).s.low,
        y_parity,
    ];
    let ownable = IOwnableDispatcher { contract_address: merkleroot_validator_configuration.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_configuration.set_validators(validators_address.span());
    merkleroot_validator_configuration.set_threshold(4);
    let bytes_metadata = BytesTrait::new(496, metadata);
    assert(merkleroot_ism.verify(bytes_metadata, message) == true, 'verification failed');
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
    let (_, validators_address, signatures) = get_message_and_signature();
    let y_parity = 0x01000000000000000000000000000000; // parity set to false
    let metadata = array![
        0x01020304050607080910111213141516,
        0x16151413121110090807060504030201,
        0x01020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x00000010000000000000000000000000,
        *signatures.at(0).r.high,
        *signatures.at(0).r.low,
        *signatures.at(0).s.high,
        *signatures.at(0).s.low,
        y_parity,
        *signatures.at(1).r.high,
        *signatures.at(1).r.low,
        *signatures.at(1).s.high,
        *signatures.at(1).s.low,
        y_parity,
        *signatures.at(2).r.high,
        *signatures.at(2).r.low,
        *signatures.at(2).s.high,
        *signatures.at(2).s.low,
        y_parity,
        *signatures.at(3).r.high + 1,
        *signatures.at(3).r.low + 1,
        *signatures.at(3).s.high + 1,
        *signatures.at(3).s.low + 1,
        y_parity,
    ];
    let ownable = IOwnableDispatcher { contract_address: merkleroot_ism.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_config.set_validators(validators_address.span());
    merkleroot_validator_config.set_threshold(4);
    let bytes_metadata = BytesTrait::new(496, metadata);
    assert(merkleroot_ism.verify(bytes_metadata, message) == true, 'verification failed');
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
    let (_, validators_address, _) = get_message_and_signature();
    let ownable = IOwnableDispatcher { contract_address: merkle_root_ism.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    merkleroot_validator_config.set_validators(validators_address.span());
    merkleroot_validator_config.set_threshold(4);
    let bytes_metadata = BytesTrait::new_empty();
    assert(merkle_root_ism.verify(bytes_metadata, message) == true, 'verification failed');
}

