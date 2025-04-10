use alexandria_bytes::{Bytes, BytesStore, BytesTrait};

use contracts::interfaces::{
    DomainRoutingHookConfig, ETH_ADDRESS, IDomainRoutingHookDispatcherTrait,
    IPostDispatchHookDispatcherTrait, IProtocolFeeDispatcherTrait, Types,
};
use contracts::libs::message::{HYPERLANE_VERSION, Message};

use contracts::utils::utils::U256TryIntoContractAddress;

use openzeppelin::access::ownable::interface::{IOwnableDispatcher};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

use snforge_std::{CheatSpan, ContractClass, cheat_caller_address, get_class_hash};

use starknet::{ContractAddress, contract_address_const};
use super::super::setup::{
    NEW_OWNER, OWNER, PROTOCOL_FEE, setup_domain_routing_hook, setup_protocol_fee,
};

#[test]
fn test_domain_routing_hook_type() {
    let (routing_hook_addrs, _) = setup_domain_routing_hook();
    assert_eq!(routing_hook_addrs.hook_type(), Types::ROUTING(()));
}

#[test]
fn test_supports_metadata_for_domain_routing_hook() {
    let (routing_hook_addrs, _) = setup_domain_routing_hook();

    let metadata = BytesTrait::new_empty();
    assert_eq!(routing_hook_addrs.supports_metadata(@metadata), true);
}

#[test]
fn test_domain_rounting_set_hook() {
    let (_, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };

    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    let destination: u32 = 12;
    let hook: ContractAddress = contract_address_const::<1>();
    set_routing_hook_addrs.set_hook(destination, hook);
    assert_eq!(set_routing_hook_addrs.get_hook(destination), hook);
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
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    let mut hook_config_arr = ArrayTrait::<DomainRoutingHookConfig>::new();
    let config_1 = DomainRoutingHookConfig { destination: 1, hook: contract_address_const::<2>() };
    let config_2 = DomainRoutingHookConfig { destination: 2, hook: contract_address_const::<3>() };
    let config_3 = DomainRoutingHookConfig { destination: 3, hook: contract_address_const::<4>() };
    hook_config_arr.append(config_1);
    hook_config_arr.append(config_2);
    hook_config_arr.append(config_3);
    set_routing_hook_addrs.set_hooks(hook_config_arr);
    assert_eq!(set_routing_hook_addrs.get_hook(config_1.destination), config_1.hook);
    assert_eq!(set_routing_hook_addrs.get_hook(config_2.destination), config_2.hook);
    assert_eq!(set_routing_hook_addrs.get_hook(config_3.destination), config_3.hook);
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
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    let destination: u32 = 12;
    let hook: ContractAddress = contract_address_const::<1>();
    set_routing_hook_addrs.set_hook(destination, hook);

    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination - 1,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();
    let protocol_fee = 12_u256;
    routing_hook_addrs.post_dispatch(@metadata, @message, protocol_fee);
}

#[test]
fn hook_set_for_destination_post_dispatch() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let fee_token_instance = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    // We define a first destination
    let destination: u32 = 18;
    let (protocol_fee, _) = setup_protocol_fee(Option::None);
    set_routing_hook_addrs.set_hook(destination, protocol_fee.contract_address);

    let protocol_fee_class_hash = get_class_hash(protocol_fee.contract_address);
    let protocol_fee_contract_class = ContractClass { class_hash: protocol_fee_class_hash };

    // We define a second destination
    let second_destination: u32 = 32;
    let (second_protocol_fee, _) = setup_protocol_fee(Option::Some(protocol_fee_contract_class));
    let new_protocol_fee = 3 * PROTOCOL_FEE;
    // We change the configuration
    let protocol_ownable = IOwnableDispatcher {
        contract_address: second_protocol_fee.contract_address,
    };
    cheat_caller_address(
        protocol_ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    second_protocol_fee.set_protocol_fee(new_protocol_fee);

    set_routing_hook_addrs.set_hook(second_destination, second_protocol_fee.contract_address);

    let message_1 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let message_2 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: second_destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();

    let erc20Ownable = IOwnableDispatcher { contract_address: ETH_ADDRESS() };
    cheat_caller_address(
        erc20Ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    fee_token_instance.transfer(NEW_OWNER().try_into().unwrap(), PROTOCOL_FEE + new_protocol_fee);

    assert_eq!(
        fee_token_instance.balance_of(NEW_OWNER().try_into().unwrap()),
        PROTOCOL_FEE + new_protocol_fee,
    );
    cheat_caller_address(
        erc20Ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    fee_token_instance
        .approve(routing_hook_addrs.contract_address, PROTOCOL_FEE + new_protocol_fee);
    assert(
        fee_token_instance
            .allowance(
                NEW_OWNER().try_into().unwrap(), routing_hook_addrs.contract_address,
            ) == PROTOCOL_FEE
            + new_protocol_fee,
        'Approve failed',
    );

    cheat_caller_address(
        ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    routing_hook_addrs.post_dispatch(@metadata, @message_1, PROTOCOL_FEE);
    assert_eq!(fee_token_instance.balance_of(NEW_OWNER().try_into().unwrap()), new_protocol_fee);

    routing_hook_addrs.post_dispatch(@metadata, @message_2, new_protocol_fee);
    assert_eq!(fee_token_instance.balance_of(NEW_OWNER().try_into().unwrap()), 0);
}


#[test]
#[should_panic(expected: 'Amount does not cover quote fee')]
fn test_post_dispatch_insufficient_fee() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };

    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    // Set up a destination with a specific hook
    let destination: u32 = 18;
    let (protocol_fee, _) = setup_protocol_fee(Option::None);
    set_routing_hook_addrs.set_hook(destination, protocol_fee.contract_address);

    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();

    // This should panic with 'Amount does not cover quote fee'
    // Assuming PROTOCOL_FEE is smaller than the required quote
    routing_hook_addrs.post_dispatch(@metadata, @message, PROTOCOL_FEE / 2);
}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_transfer_routing_fee_insufficient_balance() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };

    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    // We define a first destination
    let destination: u32 = 18;
    let (protocol_fee, _) = setup_protocol_fee(Option::None);
    set_routing_hook_addrs.set_hook(destination, protocol_fee.contract_address);

    let fee_token_instance = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };

    let message_1 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };

    let metadata = BytesTrait::new_empty();

    let erc20Ownable = IOwnableDispatcher { contract_address: ETH_ADDRESS() };
    cheat_caller_address(
        erc20Ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    // We transfer insufficient amount
    fee_token_instance.transfer(NEW_OWNER().try_into().unwrap(), PROTOCOL_FEE / 2);

    cheat_caller_address(
        erc20Ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    fee_token_instance.approve(routing_hook_addrs.contract_address, PROTOCOL_FEE);
    assert(
        fee_token_instance
            .allowance(
                NEW_OWNER().try_into().unwrap(), routing_hook_addrs.contract_address,
            ) == PROTOCOL_FEE,
        'Approve failed',
    );
    cheat_caller_address(
        ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    routing_hook_addrs.post_dispatch(@metadata, @message_1, PROTOCOL_FEE);
}

#[test]
#[should_panic(expected: 'Insufficient allowance')]
fn test_transfer_routing_fee_insufficient_allowance() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    // We define a first destination
    let destination: u32 = 18;
    let (protocol_fee, _) = setup_protocol_fee(Option::None);
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    set_routing_hook_addrs.set_hook(destination, protocol_fee.contract_address);

    let fee_token_instance = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };

    let message_1 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };

    let metadata = BytesTrait::new_empty();

    let erc20Ownable = IOwnableDispatcher { contract_address: ETH_ADDRESS() };
    cheat_caller_address(
        erc20Ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    // We transfer insufficient amount
    fee_token_instance.transfer(NEW_OWNER().try_into().unwrap(), PROTOCOL_FEE);

    cheat_caller_address(
        erc20Ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );

    fee_token_instance.approve(routing_hook_addrs.contract_address, PROTOCOL_FEE / 2);
    // Insufficient allowance for dispatch
    assert(
        fee_token_instance
            .allowance(
                NEW_OWNER().try_into().unwrap(), routing_hook_addrs.contract_address,
            ) == PROTOCOL_FEE
            / 2,
        'Approve failed',
    );

    cheat_caller_address(
        ownable.contract_address, NEW_OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    routing_hook_addrs.post_dispatch(@metadata, @message_1, PROTOCOL_FEE);
}

#[test]
fn hook_set_for_destination_quote_dispatch() {
    let (routing_hook_addrs, set_routing_hook_addrs) = setup_domain_routing_hook();
    let ownable = IOwnableDispatcher { contract_address: set_routing_hook_addrs.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    // We define a first destination
    let destination: u32 = 18;
    let (protocol_fee, _) = setup_protocol_fee(Option::None);
    set_routing_hook_addrs.set_hook(destination, protocol_fee.contract_address);

    let protocol_fee_class_hash = get_class_hash(protocol_fee.contract_address);
    let protocol_fee_contract_class = ContractClass { class_hash: protocol_fee_class_hash };
    // We define a second destination
    let second_destination: u32 = 32;
    let (second_protocol_fee, _) = setup_protocol_fee(Option::Some(protocol_fee_contract_class));
    let new_protocol_fee = 3 * PROTOCOL_FEE;
    // We change the configuration
    let protocol_ownable = IOwnableDispatcher {
        contract_address: second_protocol_fee.contract_address,
    };
    cheat_caller_address(
        protocol_ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    second_protocol_fee.set_protocol_fee(new_protocol_fee);
    set_routing_hook_addrs.set_hook(second_destination, second_protocol_fee.contract_address);

    let message_1 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let message_2 = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: 0,
        destination: second_destination,
        recipient: 0,
        body: BytesTrait::new_empty(),
    };
    let metadata = BytesTrait::new_empty();
    assert_eq!(routing_hook_addrs.quote_dispatch(@metadata, @message_1), PROTOCOL_FEE);
    assert_eq!(routing_hook_addrs.quote_dispatch(@metadata, @message_2), new_protocol_fee);
}
