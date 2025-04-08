use alexandria_bytes::{Bytes, BytesTrait};
use contracts::interfaces::{
    IAggregationDispatcher, IAggregationDispatcherTrait, IInterchainSecurityModuleDispatcher,
    IInterchainSecurityModuleDispatcherTrait, IValidatorConfigurationDispatcher,
    IValidatorConfigurationDispatcherTrait, ModuleType,
};
use contracts::isms::aggregation::aggregation;
use contracts::libs::message::{HYPERLANE_VERSION, Message};
use contracts::utils::utils::U256TryIntoContractAddress;

use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpy, cheat_caller_address,
    cheatcodes::contract_class::ContractClass, declare, spy_events,
};


use starknet::ContractAddress;
use super::super::setup::{
    CONTRACT_MODULES, DESTINATION_DOMAIN, LOCAL_DOMAIN, MODULES, OWNER, VALID_OWNER,
    VALID_RECIPIENT, build_messageid_metadata, get_message_and_signature, setup_aggregation,
    setup_messageid_multisig_ism, setup_noop_ism,
};

#[test]
fn test_aggregation_module_type() {
    let threshold = 2;
    let aggregation = setup_aggregation(MODULES(), threshold);
    assert(
        aggregation.module_type() == ModuleType::AGGREGATION(aggregation.contract_address),
        'Aggregation: Wrong module type',
    );
}

#[test]
#[should_panic]
fn test_aggregation_initialize_with_too_many_modules() {
    let threshold = 2;
    let mut modules = array![];
    let mut cur_idx = 0;
    loop {
        if (cur_idx == 256) {
            break;
        }
        modules.append('module_1'.into());
        cur_idx += 1;
    };
    setup_aggregation(modules.span(), threshold);
}


#[test]
#[should_panic]
fn test_setup_aggregation_with_null_module_address() {
    let threshold = 2;
    let modules: Span<felt252> = array![0, 'module_1'].span();
    setup_aggregation(modules, threshold);
}

#[test]
fn test_get_modules() {
    let threshold = 2;
    let aggregation = setup_aggregation(MODULES(), threshold);
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    assert(aggregation.get_modules() == CONTRACT_MODULES(), 'set modules failed');
}


#[test]
fn test_aggregation_verify() {
    let threshold = 2;

    // MESSAGEID

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
    let (_, validators_address, _) = get_message_and_signature();
    let (messageid, _) = setup_messageid_multisig_ism(validators_address.span(), threshold);
    let origin_merkle_tree: u256 = 'origin_merkle_tree_hook'.try_into().unwrap();
    let root: u256 = 'root'.try_into().unwrap();
    let index = 1;
    let message_id_metadata = build_messageid_metadata(origin_merkle_tree, root, index);
    // Noop ism
    let noop_ism = setup_noop_ism();
    let aggregation = setup_aggregation(
        array![messageid.contract_address.into(), noop_ism.contract_address.into()].span(),
        threshold.try_into().unwrap(),
    );
    let ownable = IOwnableDispatcher { contract_address: aggregation.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    let mut concat_metadata = BytesTrait::new_empty();
    concat_metadata.append_u128(0x00000010000001A0000001A0000001A9);
    concat_metadata.concat(@message_id_metadata);
    // dummy metadata for noop ism
    concat_metadata.concat(@message_id_metadata);
    assert(aggregation.verify(concat_metadata, message), 'Aggregation: verify failed');
}


#[test]
fn test_aggregation_verify_e2e() {
    let aggregation_threshold = 1;

    // MESSAGEID
    let message_body = BytesTrait::new(11, array![0x68656C6C6F20776F726C640000000000]);
    let metadata = BytesTrait::new(
        144,
        array![
            0x000000080000008d071e1b5e54086bbd,
            0xe2b7a131a2c913f442485974c32df56e,
            0xe47f9456b3270daebe22faba5bc0223a,
            0x7e3077adcd04391f2ccdd2b2ad2eac2d,
            0x71c3f04755d5d95d000000015dcbf07f,
            0xa1898b0d8b64991f099e8478268fb36e,
            0x0e5fe7832aa345da8b8888645622786d,
            0x53d898c95d75d37a582de78deda23497,
            0x7d806349eac6653e9190d11a1c000000,
        ],
    );
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: 23448593,
        sender: 0x00b3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca,
        destination: 23448594,
        recipient: 0x0777c88c0822f31828c97688a219af6b6689cae7bc90a7aa71437956dfed16a1,
        body: message_body.clone(),
    };

    let multisig_threshold = 1;
    let validators_array: Array<felt252> = array![
        0x15d34aaf54267db7d7c367839aaf71a00a2c6a65.try_into().unwrap(),
    ];

    // TODO
    // Deploy the messageid contract at a specific address
    let specific_address: ContractAddress =
        0x045133e4b0a40aa7992bfb5d7f552b767be1b070af81f0313adf8e01cf3ab32c
        .try_into()
        .unwrap();
    let messageid_class = declare("messageid_multisig_ism").unwrap().contract_class();
    let mut parameters = Default::default();
    let owner: felt252 = 0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca
        .try_into()
        .unwrap();
    Serde::serialize(@owner, ref parameters);
    Serde::serialize(@validators_array.span(), ref parameters);
    Serde::serialize(@multisig_threshold, ref parameters);
    messageid_class.deploy_at(@parameters, specific_address);

    let messageid_ism = IInterchainSecurityModuleDispatcher { contract_address: specific_address };
    // println!("E2E test messageid_ism: {}", messageid_ism.contract_address());

    let aggregation = setup_aggregation(
        array![messageid_ism.contract_address.into()].span(),
        aggregation_threshold.try_into().unwrap(),
    );

    assert(aggregation.verify(metadata, message), 'Aggregation: verify failed');
}

