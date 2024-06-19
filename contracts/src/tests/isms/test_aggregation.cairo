use alexandria_bytes::{Bytes, BytesTrait};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::interfaces::{
    ModuleType, IAggregationDispatcher, IAggregationDispatcherTrait,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IValidatorConfigurationDispatcher, IValidatorConfigurationDispatcherTrait,
};
use hyperlane_starknet::tests::setup::{
    setup_aggregation, OWNER, setup_messageid_multisig_ism, get_message_and_signature, LOCAL_DOMAIN,
    DESTINATION_DOMAIN, build_messageid_metadata, VALID_OWNER, VALID_RECIPIENT, setup_noop_ism
};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{start_prank, CheatTarget};
use starknet::ContractAddress;

#[test]
fn test_aggregation_module_type() {
    let aggregation = setup_aggregation();
    assert(
        aggregation.module_type() == ModuleType::AGGREGATION(aggregation.contract_address),
        'Aggregation: Wrong module type'
    );
}

#[test]
fn test_aggregation_set_threshold() {
    let threshold = 3;
    let aggregation = setup_aggregation();
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    aggregation.set_threshold(threshold);
}

#[test]
#[should_panic(expected: ('Threshold not set',))]
fn test_aggregation_verify_fails_if_treshold_not_set() {
    let aggregation = setup_aggregation();
    aggregation.verify(BytesTrait::new(42, array![]), MessageTrait::default());
}

#[test]
fn test_set_modules() {
    let aggregation = setup_aggregation();
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let module_1: ContractAddress = 'module_1'.try_into().unwrap();
    let module_2: ContractAddress = 'module_2'.try_into().unwrap();
    aggregation.set_modules(array![module_1, module_2].span());
    assert(aggregation.get_modules() == array![module_1, module_2].span(), 'set modules failed');
}

#[test]
#[should_panic(expected: ('Modules already stored',))]
fn test_set_modules_fails_if_already_added_module() {
    let aggregation = setup_aggregation();
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let module_1: ContractAddress = 'module_1'.try_into().unwrap();
    let module_2: ContractAddress = 'module_2'.try_into().unwrap();
    aggregation.set_modules(array![module_1, module_2].span());
    assert(aggregation.get_modules() == array![module_1, module_2].span(), 'set modules failed');
    aggregation.set_modules(array![module_1].span());
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_module_fails_if_caller_is_not_owner() {
    let aggregation = setup_aggregation();
    let module_1: ContractAddress = 'module_1'.try_into().unwrap();
    let module_2: ContractAddress = 'module_2'.try_into().unwrap();
    aggregation.set_modules(array![module_1, module_2].span());
    assert(aggregation.get_modules() == array![module_1, module_2].span(), 'set modules failed');
}

#[test]
fn test_aggregation_verify() {
    let aggregation = setup_aggregation();
    let threshold = 2;

    // MESSAGEID 

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
        sender: VALID_OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: VALID_RECIPIENT(),
        body: message_body.clone()
    };
    let (messageid, messageid_validator_configuration) = setup_messageid_multisig_ism();
    let (_, validators_address, _) = get_message_and_signature();
    let origin_merkle_tree: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let root: u256 = 'root'.try_into().unwrap();
    let index = 1;
    let message_id_metadata = build_messageid_metadata(origin_merkle_tree, root, index);
    let ownable = IOwnableDispatcher {
        contract_address: messageid_validator_configuration.contract_address
    };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    messageid_validator_configuration.set_validators(validators_address.span());
    messageid_validator_configuration.set_threshold(5);
    // Noop ism
    let noop_ism = setup_noop_ism();

    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    aggregation.set_threshold(threshold);
    let mut concat_metadata = BytesTrait::new_empty();
    concat_metadata.append_u128(0x00000010000001A0000001A0000001A9);
    concat_metadata.concat(@message_id_metadata);
    // dummy metadata for noop ism
    concat_metadata.concat(@message_id_metadata);
    aggregation
        .set_modules(
            array![messageid.contract_address.into(), noop_ism.contract_address.into(),].span()
        );
    assert(aggregation.verify(concat_metadata, message), 'Aggregation: verify failed');
}

