pub mod checkpoint_lib {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use core::keccak::keccak_u256s_be_inputs;
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::utils::keccak256::reverse_endianness;


    pub trait CheckpointLib {
        fn digest(
            _origin: u32,
            _origin_merkle_tree_hook: u256,
            _checkpoint_root: u256,
            _checkpoint_index: u32,
            _message_id: u256
        ) -> u256;
        fn domain_hash(_origin: u32, _origin_merkle_tree_hook: u256) -> u256;
    }
    const HYPERLANE: felt252 = 'HYPERLANE';
    pub const HYPERLANE_ANNOUNCEMENT: felt252 = 'HYPERLANE_ANNOUNCEMENT';

    impl CheckpointLibImpl of CheckpointLib {
        fn digest(
            _origin: u32,
            _origin_merkle_tree_hook: u256,
            _checkpoint_root: u256,
            _checkpoint_index: u32,
            _message_id: u256
        ) -> u256 {
            let domain_hash = CheckpointLib::domain_hash(_origin, _origin_merkle_tree_hook);
            let mut input: Array<u256> = array![
                domain_hash.into(),
                _checkpoint_root.into(),
                _checkpoint_index.into(),
                _message_id.into(),
            ];
            let hash = keccak_u256s_be_inputs(input.span());
            reverse_endianness(hash)
        }

        fn domain_hash(_origin: u32, _origin_merkle_tree_hook: u256) -> u256 {
            let mut input: Array<u256> = array![
                _origin.into(), _origin_merkle_tree_hook.into(), HYPERLANE.into()
            ];
            let hash = keccak_u256s_be_inputs(input.span());
            reverse_endianness(hash)
        }
    }
}

