use alexandria_bytes::{Bytes, BytesTrait};
use core::option::OptionTrait;
use core::traits::TryInto;
use hyperlane_starknet::contracts::hooks::merkle_tree_hook::merkle_tree_hook;
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait, HYPERLANE_VERSION};
use hyperlane_starknet::interfaces::{
    Types, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait, IMerkleTreeHook,
    IMailboxDispatcher, IMailboxDispatcherTrait, IMerkleTreeHookDispatcher,
    IMerkleTreeHookDispatcherTrait
};
use hyperlane_starknet::tests::setup::{
    setup_merkle_tree_hook, setup, MAILBOX, RECIPIENT_ADDRESS, OWNER, LOCAL_DOMAIN
};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::cheatcodes::events::EventAssertions;
use snforge_std::{start_prank, CheatTarget, stop_prank};
use starknet::contract_address_const;

#[test]
fn test_merkle_tree_hook_type() {
    let (_, merkle_tree_hook, _) = setup_merkle_tree_hook();
    assert_eq!(merkle_tree_hook.hook_type(), Types::MERKLE_TREE(()));
}

#[test]
fn test_supports_metadata() {
    let mut metadata = BytesTrait::new_empty();
    let (_, merkle_tree_hook, _) = setup_merkle_tree_hook();
    assert_eq!(merkle_tree_hook.supports_metadata(metadata.clone()), true);
    let variant = 1;
    metadata.append_u16(variant);
    assert_eq!(merkle_tree_hook.supports_metadata(metadata), true);
    metadata = BytesTrait::new_empty();
    metadata.append_u16(variant + 1);
    assert_eq!(merkle_tree_hook.supports_metadata(metadata), false);
}


#[test]
fn test_post_dispatch() {
    let (merkle_tree, post_dispatch_hook, mut spy) = setup_merkle_tree_hook();
    let mailbox = IMailboxDispatcher { contract_address: MAILBOX() };
    let ownable = IOwnableDispatcher { contract_address: MAILBOX() };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let destination: u32 = 'de'.try_into().unwrap();
    let id = mailbox
        .dispatch(
            destination, RECIPIENT_ADDRESS(), BytesTrait::new_empty(), Option::None, Option::None
        );
    let nonce = mailbox.nonce();
    let count = merkle_tree.count();
    let mut metadata = BytesTrait::new_empty();
    let variant = 1;
    metadata.append_u16(variant);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: nonce,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: destination,
        recipient: RECIPIENT_ADDRESS(),
        body: BytesTrait::new_empty(),
    };
    post_dispatch_hook.post_dispatch(metadata, message);
    let expected_event = merkle_tree_hook::Event::InsertedIntoTree(
        merkle_tree_hook::InsertedIntoTree { id: id, index: count.try_into().unwrap() }
    );
    spy.assert_emitted(@array![(merkle_tree.contract_address, expected_event),]);
    assert_eq!(merkle_tree.count(), count + 1);
}

#[test]
#[should_panic(expected: ('Message not dispatching',))]
fn test_post_dispatch_fails_if_message_not_dispatching() {
    let (_, post_dispatch_hook, _) = setup_merkle_tree_hook();
    let mut metadata = BytesTrait::new_empty();
    let variant = 1;
    metadata.append_u16(variant);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0_u32,
        origin: 0_u32,
        sender: contract_address_const::<0x123>(),
        destination: 0_u32,
        recipient: contract_address_const::<0x1222>(),
        body: BytesTrait::new_empty(),
    };
    post_dispatch_hook.post_dispatch(metadata, message);
}
#[test]
#[should_panic(expected: ('Invalid metadata variant',))]
fn test_post_dispatch_fails_if_invalid_variant() {
    let (_, post_dispatch_hook, _) = setup_merkle_tree_hook();
    let mut metadata = BytesTrait::new_empty();
    let variant = 2;
    metadata.append_u16(variant);
    let message = MessageTrait::default();
    post_dispatch_hook.post_dispatch(metadata, message);
}


#[test]
fn test_quote_dispatch() {
    let (_, post_dispatch_hook, _) = setup_merkle_tree_hook();
    let mut metadata = BytesTrait::new_empty();
    let variant = 1;
    metadata.append_u16(variant);
    let message = MessageTrait::default();
    post_dispatch_hook.quote_dispatch(metadata, message);
}

#[test]
#[should_panic(expected: ('Invalid metadata variant',))]
fn test_quote_dispatch_fails_if_invalid_variant() {
    let (_, post_dispatch_hook, _) = setup_merkle_tree_hook();
    let mut metadata = BytesTrait::new_empty();
    let variant = 2;
    metadata.append_u16(variant);
    let message = MessageTrait::default();
    post_dispatch_hook.quote_dispatch(metadata, message);
}

#[test]
fn test_count() {
    let (merkle_tree, post_dispatch_hook, mut spy) = setup_merkle_tree_hook();
    let count = merkle_tree.count();
    println!("dcfskdmfksldfl{}", count);
}
