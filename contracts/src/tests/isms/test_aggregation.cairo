use alexandria_bytes::{Bytes, BytesTrait};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::interfaces::{
    ModuleType, IAggregation, IAggregationDispatcher, IAggregationDispatcherTrait,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IValidatorConfigurationDispatcher, IValidatorConfigurationDispatcherTrait,
    IValidatorConfiguration, IInterchainSecurityModule
};
use hyperlane_starknet::tests::setup::{
    setup_aggregation, OWNER, setup_messageid_multisig_ism, get_message_and_signature, LOCAL_DOMAIN,
    DESTINATION_DOMAIN, RECIPIENT_ADDRESS
};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{start_prank, CheatTarget, stop_prank};

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
#[ignore]
fn test_aggregation_verify() {
    let (messageid, messageid_validator_config) = setup_messageid_multisig_ism();
    let aggregation = setup_aggregation();
    let threshold = 1; // TO BE COMPLETED ONCE OTHER ISMS ARE IMPLEMENTED
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
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
    let ownable = IOwnableDispatcher { contract_address: messageid.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    messageid_validator_config.set_validators(validators_address.span());
    aggregation.set_threshold(threshold);
    let bytes_metadata = BytesTrait::new(496, metadata);
    aggregation.set_modules(array![messageid.contract_address.into()].span());
    assert(aggregation.verify(bytes_metadata, message), 'Aggregation: verify failed');
}

