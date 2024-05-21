use alexandria_bytes::{Bytes, BytesTrait};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
use hyperlane_starknet::interfaces::{
    ModuleType, IAggregation, IAggregationDispatcher, IAggregationDispatcherTrait
};

use hyperlane_starknet::tests::setup::{setup_aggregation, OWNER};

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
    let aggregation = setup_aggregation();
}

#[test]
#[should_panic(expected: ('Threshold not set',))]
fn test_aggregation_verify_fails_if_treshold_not_set() {
    let aggregation = setup_aggregation();
    aggregation.verify(BytesTrait::new(42, array![]), MessageTrait::default());
}

