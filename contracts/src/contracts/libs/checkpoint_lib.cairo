pub mod checkpoint_lib {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::utils::keccak256::{
        reverse_endianness, compute_keccak, ByteData, u64_word_size, u256_word_size, HASH_SIZE
    };


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
                ByteData { value: domain_hash.into(), size: HASH_SIZE },
                ByteData {
                    value: _checkpoint_root.into(),
                    size: u256_word_size(_checkpoint_root.into()).into()
                },
                ByteData {
                    value: _checkpoint_index.into(),
                    size: u64_word_size(_checkpoint_index.into()).into()
                },
                ByteData { value: _message_id.into(), size: HASH_SIZE },
            ];
            compute_keccak(input.span())
        }

        fn domain_hash(_origin: u32, _origin_merkle_tree_hook: u256) -> u256 {
            let mut input: Array<ByteData> = array![
                ByteData { value: _origin.into(), size: u64_word_size(_origin.into()).into() },
                ByteData {
                    value: _origin_merkle_tree_hook.into(),
                    size: u256_word_size(_origin_merkle_tree_hook).into()
                },
                ByteData { value: HYPERLANE.into(), size: 9 }
            ];
            compute_keccak(input.span())
        }
    }
}

