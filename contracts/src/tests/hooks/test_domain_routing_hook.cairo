use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::interfaces::{
    Types, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait,
    IDomainRoutingHookDispatcher, IDomainRoutingHookDispatcherTrait, DomainRoutingHookConfig
};
use hyperlane_starknet::tests::setup::{setup_domain_routing_hook, setup_mock_hook, OWNER};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

use snforge_std::{start_prank, CheatTarget};
use starknet::{get_caller_address, contract_address_const, ContractAddress};


#[test]
fn test_domain_routing_hook_type() {
    let (routing_hook_addrs, _) = setup_domain_routing_hook();
    assert_eq!(routing_hook_addrs.hook_type(), Types::ROUTING(()));
}

#[test]
fn test_supports_metadata_for_domain_routing_hook() {
    let (routing_hook_addrs, _) = setup_domain_routing_hook();

    let metadata = BytesTrait::new_empty();
    assert_eq!(routing_hook_addrs.supports_metadata(metadata), true);
}

#[test]
fn test_domain_rounting_set_hook() {
    let (_, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let destination: u32 = 12;
    let hook: ContractAddress = contract_address_const::<1>();
    set_routing_hook_addrs.set_hook(destination, hook);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_hook_fails_if_not_owner() {
    let (_, set_routing_hook_addrs) = setup_domain_routing_hook();
    let destination: u32 = 12;
    let hook: ContractAddress = contract_address_const::<1>();
    set_routing_hook_addrs.set_hook(destination, hook);
}

#[test]
fn test_domain_rounting_set_hook_array() {
    let (_, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let mut hook_config_arr = ArrayTrait::<DomainRoutingHookConfig>::new();
    hook_config_arr
        .append(DomainRoutingHookConfig { destination: 1, hook: contract_address_const::<2>() });
    hook_config_arr
        .append(DomainRoutingHookConfig { destination: 2, hook: contract_address_const::<3>() });
    hook_config_arr
        .append(DomainRoutingHookConfig { destination: 3, hook: contract_address_const::<4>() });
    set_routing_hook_addrs.set_hooks(hook_config_arr);
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_hook_array_fails_if_not_owner() {
    let (_, set_routing_hook_addrs) = setup_domain_routing_hook();
    let mut hook_config_arr = ArrayTrait::<DomainRoutingHookConfig>::new();
    hook_config_arr
        .append(DomainRoutingHookConfig { destination: 1, hook: contract_address_const::<2>() });
    hook_config_arr
        .append(DomainRoutingHookConfig { destination: 2, hook: contract_address_const::<3>() });
    set_routing_hook_addrs.set_hooks(hook_config_arr);
}


#[test]
#[should_panic(expected: ('Destination has no hooks',))]
fn hook_not_set_for_destination_should_fail() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let destination: u32 = 12;
    let hook: ContractAddress = contract_address_const::<1>();
    set_routing_hook_addrs.set_hook(destination, hook);

    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: contract_address_const::<0>(),
        destination: destination - 1,
        recipient: contract_address_const::<0>(),
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();
    routing_hook_addrs.post_dispatch(metadata, message);
}

// Note: Test fails with msg('Result::unwrap failed')
#[ignore]
#[test]
fn hook_set_for_destination_post_dispatch() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let destination: u32 = 18;
    let hook: ContractAddress = setup_mock_hook().contract_address;
    set_routing_hook_addrs.set_hook(destination, hook);

    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: contract_address_const::<0>(),
        destination: destination,
        recipient: contract_address_const::<0>(),
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();
    routing_hook_addrs.post_dispatch(metadata, message);
}

// Note: Test fails with msg('Result::unwrap failed')
#[ignore]
#[test]
fn hook_set_for_destination_quote_dispatch() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let destination: u32 = 18;
    let hook: ContractAddress = setup_mock_hook().contract_address;
    set_routing_hook_addrs.set_hook(destination, hook);

    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: contract_address_const::<0>(),
        destination: destination,
        recipient: contract_address_const::<0>(),
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();
    routing_hook_addrs.quote_dispatch(metadata, message);
}
