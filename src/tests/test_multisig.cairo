use alexandria_bytes::{Bytes, BytesTrait};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use core::array::ArrayTrait;
use core::array::SpanTrait;
use hyperlane_starknet::contracts::isms::multisig::multisig_ism::multisig_ism::ValidatorInformations;
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
use hyperlane_starknet::contracts::libs::multisig::message_id_ism_metadata::message_id_ism_metadata::MessageIdIsmMetadata;
use hyperlane_starknet::contracts::mailbox::mailbox;
use hyperlane_starknet::interfaces::IMessageRecipientDispatcherTrait;
use hyperlane_starknet::interfaces::IMultisigIsmDispatcherTrait;
use hyperlane_starknet::interfaces::{
    IMailbox, IMailboxDispatcher, IMailboxDispatcherTrait, HYPERLANE_VERSION, ModuleType,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait
};
use hyperlane_starknet::tests::setup::{
    setup, mock_setup, setup_messageid_multisig_ism, setup_multisig_ism, OWNER, NEW_OWNER,
    VALIDATOR_ADDRESS, VALIDATOR_PUBLIC_KEY,setup_validator_announce, get_message_and_signature, LOCAL_DOMAIN, DESTINATION_DOMAIN,RECIPIENT_ADDRESS
};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::cheatcodes::events::EventAssertions;
use snforge_std::{start_prank, CheatTarget, stop_prank};
use starknet::eth_address::EthAddress;
#[test]
fn test_set_validators() {
    let new_validators = array![
        ValidatorInformations { address: VALIDATOR_ADDRESS(), public_key: VALIDATOR_PUBLIC_KEY() }
    ]
        .span();
    let validators = setup_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    validators.set_validators(new_validators);
    let validators_span = validators.get_validators();
    assert(validators_span == new_validators, 'wrong validator address def');
}


#[test]
fn test_set_threshold() {
    let new_threshold = 3;
    let validators = setup_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    validators.set_threshold(new_threshold);
    assert(validators.get_threshold() == new_threshold, 'wrong validator threshold');
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_validators_fails_if_caller_not_owner() {
    let new_validators = array![
        ValidatorInformations { address: VALIDATOR_ADDRESS(), public_key: VALIDATOR_PUBLIC_KEY() }
    ]
        .span();
    let validators = setup_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    validators.set_validators(new_validators);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_threshold_fails_if_caller_not_owner() {
    let new_threshold = 3;
    let validators = setup_multisig_ism();
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    validators.set_threshold(new_threshold);
}


#[test]
fn test_message_id_ism_metadata() {
    let origin_merkle_tree_hook = array![
        // origin_merkle_tree_hook
        0x01020304050607080910111213141516,
        0x16151413121110090807060504030201];
    let root = array![
        0x01020304050607080910111213141516,
        0x01020304050607080920111213141516,
    ];
    let index = array![0x00000013000000000000000000000000];
    let index_u32 = 0x13;
    let signature_1 = array![
        0x01020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x00000003000000000000000000000000
    ];
    let signature_2 = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
        0x00000002000000000000000000000000
    ];
    let signature_3 = array![
        0x01020304050607080910111213141516,
        0x13092450000011115450564500700000,
        0x01020304050607080910000000000000,
        0x01020304050607080910111213141516,
        0x00000002000000000000000000000000
    ];
    let signature_1_v = 0x3;
    let signature_2_v = 0x2;
    let signature_3_v = 0x2;
    let mut metadata = origin_merkle_tree_hook.concat(@root);
    metadata = metadata.concat(@index);
    metadata = metadata.concat(@signature_1);
    metadata = metadata.concat(@signature_2);
    metadata = metadata.concat(@signature_3);
    let bytes_metadata = BytesTrait::new(496, metadata);
    assert(
        MessageIdIsmMetadata::origin_merkle_tree_hook(bytes_metadata.clone()) == u256 {low: *origin_merkle_tree_hook.at(1), high: *origin_merkle_tree_hook.at(0)},
        'wrong merkle tree hook'
    );
    assert(
        MessageIdIsmMetadata::root(bytes_metadata.clone()) == u256 {low: *root.at(1), high: *root.at(0)},
        'wrong root'
    );
    assert(
        MessageIdIsmMetadata::index(bytes_metadata.clone()) == index_u32,
        'wrong index'
    );
    let (test, test_1, test_2) = MessageIdIsmMetadata::signature_at(bytes_metadata.clone(),1);
    println!("aight {}, {}, {}",test, test_1, test_2);
    assert(
        MessageIdIsmMetadata::signature_at(bytes_metadata.clone(),0) == (signature_1_v, u256{low:*signature_1.at(1), high: *signature_1.at(0) }, u256 {low: *signature_1.at(3), high: *signature_1.at(2)}),
        'wrong signature 1'
    );
    assert(
        MessageIdIsmMetadata::signature_at(bytes_metadata.clone(),1) == (signature_2_v, u256{low:*signature_2.at(1), high: *signature_2.at(0) }, u256 {low: *signature_2.at(3), high: *signature_2.at(2)}),
        'wrong signature 2'
    );
    assert(
        MessageIdIsmMetadata::signature_at(bytes_metadata.clone(),2) == (signature_3_v, u256{low:*signature_3.at(1), high: *signature_3.at(0) }, u256 {low: *signature_3.at(3), high: *signature_3.at(2)}),
        'wrong signature 3'
    );
}


#[test]
fn test_message_id_multisig_module_type() {
    let messageid = setup_messageid_multisig_ism();
    assert(
        messageid.module_type() == ModuleType::MESSAGE_ID_MULTISIG(messageid.contract_address),
        'Wrong module type'
    );
}


#[test]
fn test_message_id_multisig_verify() {
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
    let messageid = setup_messageid_multisig_ism();
    let (msg_hash, signature, public_key_x, public_key_y, eth_address) = get_message_and_signature(false);
    let validators = setup_multisig_ism();
    let new_validators = array![
        ValidatorInformations { address: eth_address, public_key: 0.try_into().unwrap()}
    ];
    let metadata = array![ 
        0x01020304050607080910111213141516,
         0x16151413121110090807060504030201, 
         0x01020304050607080910111213141516,
         0x01020304050607080920111213141516,
         0x00000010000000000000000000000000, 
        signature.r.high,
        signature.r.low ,
        signature.s.high,
        signature.s.low, 
        0x00000010000000000000000000000000
         ];
    let ownable = IOwnableDispatcher { contract_address: validators.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    validators.set_validators(new_validators.span());
    validators.set_threshold(1);
    let bytes_metadata = BytesTrait::new(42, metadata);
    assert(messageid.verify(bytes_metadata, message,validators.contract_address) == true, 'verification failed');
}