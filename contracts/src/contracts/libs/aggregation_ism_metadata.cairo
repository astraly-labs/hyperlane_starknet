
pub mod aggregation_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::result::{ResultTrait,Result};


    pub trait AggregationIsmMetadata {
        fn metadata_at(_metadata: Bytes, _index: u8) -> Bytes; 
        fn has_metadata(_metadata: Bytes, _index: u8) -> bool;
    }

    const RANGE_SIZE : u8 = 4;

    impl AggregationIsmMetadataImpl of AggregationIsmMetadata {
       fn metadata_at(_metadata: Bytes, _index: u8) -> Bytes {

            let (start, end) = match metadata_range(_metadata.clone(), _index) {
                Result::Ok((start, end)) => (start,end),
                Result::Err(_) => (0,0)
            };
            let (_,res) = _metadata.read_u128_packed(start,end-start);
            BytesTrait::new(16,array![res])
       }
       fn has_metadata(_metadata: Bytes, _index: u8) -> bool{
            match metadata_range(_metadata, _index) {
                Result::Ok((_,_)) => true, 
                Result::Err(_) => false
            }
       }
       
    }

    fn metadata_range(_metadata: Bytes, _index: u8 ) -> Result<(u32, u32), u8> {
        let start = _index.into() *RANGE_SIZE *2;
        let mid = start + RANGE_SIZE;
        let (_,mid_metadata) = _metadata.read_u32(mid.into());
        let (_,start_metadata) = _metadata.read_u32(start.into());
        Result::Ok((start_metadata, mid_metadata))
    }
}