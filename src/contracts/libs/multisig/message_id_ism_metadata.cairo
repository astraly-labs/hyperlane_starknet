pub mod message_id_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};


   pub trait MessageIdIsmMetadata {
    fn origin_merkle_tree_hook(_metadata: Span<Bytes>) -> u256;
    fn root(_metadata: Span<Bytes>) -> u256; 
    fn index(_metadata: Span<Bytes>) -> u32;
    fn signature_at(_metadata: Span<Bytes>, _index : u32) -> (u8, u256, u256); 
   }
   const ORIGIN_MERKLE_TREE_OFFSET: u32 = 0;
   const MERKLE_ROOT_OFFSET : u32= 32;
   const MERKLE_INDEX_OFFSET : u32= 64;
   const SIGNATURES_OFFSET : u32= 68;
   const SIGNATURE_LENGTH : u32= 65;

   impl MessagIdIsmMetadataImpl of MessageIdIsmMetadata {

    fn origin_merkle_tree_hook(_metadata:Span<Bytes>) -> u256 {
        let merkle_tree_hook_bytes = _metadata[0];
        let (_, felt) = merkle_tree_hook_bytes.read_u256(1); 
        felt
    }

    fn root(_metadata: Span<Bytes>) -> u256 {
        let root_bytes = _metadata[1];
        let (_, felt) = root_bytes.read_u256(1); 
        felt
    }

    fn index(_metadata: Span<Bytes>) -> u32 {
        let index_bytes = _metadata[2];
        let (_, felt) = index_bytes.read_u32(0); 
        felt
    }

    fn signature_at(_metadata:Span<Bytes>, _index: u32) -> (u8, u256, u256) {
        // the first signer index is 0
        let signature_initial_index = 5;
        let (_,r) = _metadata[signature_initial_index + 2*_index].read_u256(1); 
        let (_,s) = _metadata[signature_initial_index + 2*_index + 1].read_u256(1);
        let (_,v) = _metadata[signature_initial_index + 2*_index + 1].read_u8(0); 
        (v,r,s)
    }


   }

}