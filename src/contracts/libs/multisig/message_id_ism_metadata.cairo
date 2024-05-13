pub mod message_id_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};


    pub trait MessageIdIsmMetadata {
        fn origin_merkle_tree_hook(_metadata: Bytes) -> u256;
        fn root(_metadata: Bytes) -> u256;
        fn index(_metadata: Bytes) -> u32;
        fn signature_at(_metadata: Bytes, _index: u32) -> (u8, u256, u256);
    }
    pub const ORIGIN_MERKLE_TREE_HOOK_OFFSET: u32 = 0;
    pub const ROOT_OFFSET: u32 = 32;
    pub const INDEX_OFFSET: u32 = 64;
    pub const SIGNATURE_OFFSET: u32 = 96;
    impl MessagIdIsmMetadataImpl of MessageIdIsmMetadata {
        fn origin_merkle_tree_hook(_metadata: Bytes) -> u256 {
            let (_, felt) = _metadata.read_u256(ORIGIN_MERKLE_TREE_HOOK_OFFSET);
            felt
        }

        fn root(_metadata: Bytes) -> u256 {
            let (_, felt) = _metadata.read_u256(ROOT_OFFSET);
            felt
        }

        fn index(_metadata: Bytes) -> u32 {
            let (_, felt) = _metadata.read_u32(INDEX_OFFSET);
            felt
        }

        fn signature_at(_metadata: Bytes, _index: u32) -> (u8, u256, u256) {
            // the first signer index is 0
            let (_, r) = _metadata.read_u256(SIGNATURE_OFFSET + 96 * _index);
            let (_, s) = _metadata.read_u256(SIGNATURE_OFFSET + 96 * _index );
            let (_, v) = _metadata.read_u8(SIGNATURE_OFFSET + 96 * _index + 32);
            (v, r, s)
        }
    }
}
