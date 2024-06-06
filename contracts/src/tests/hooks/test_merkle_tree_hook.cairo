use hyperlane_starknet::interfaces::Types;
use hyperlane_starknet::tests::setup::{setup_merkle_tree_hook};


#[test]
fn test_merkle_tree_hook_type() {
    let merkle_tree_hook = setup_merkle_tree_hook();
    assert_eq!(merkle_tree_hook.hook_type(), Types::MERKLE_TREE(()));
}

