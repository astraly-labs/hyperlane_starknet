pub mod checkpoint_lib {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::utils::keccak256::{reverse_endianness, compute_keccak, ByteData};


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
            let mut input: Array<ByteData> = array![
                ByteData { value: domain_hash.into(), is_address: false },
                ByteData { value: _checkpoint_root.into(), is_address: false },
                ByteData { value: _checkpoint_index.into(), is_address: false },
                ByteData { value: _message_id.into(), is_address: false },
            ];
            compute_keccak(input.span())
        }

        fn domain_hash(_origin: u32, _origin_merkle_tree_hook: u256) -> u256 {
            let mut input: Array<ByteData> = array![
                ByteData { value: _origin.into(), is_address: false },
                ByteData { value: _origin_merkle_tree_hook.into(), is_address: false },
                ByteData { value: HYPERLANE.into(), is_address: false }
            ];
            compute_keccak(input.span())
        }
    }
}

