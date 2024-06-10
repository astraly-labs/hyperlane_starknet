pub mod aggregation_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::result::{ResultTrait, Result};

    pub trait AggregationIsmMetadata {
        fn metadata_at(_metadata: Bytes, _index: u8) -> Bytes;
        fn has_metadata(_metadata: Bytes, _index: u8) -> bool;
    }

    const RANGE_SIZE: u8 = 4;
    const BYTES_PER_ELEMENT: u8 = 16;

    impl AggregationIsmMetadataImpl of AggregationIsmMetadata {
        fn metadata_at(_metadata: Bytes, _index: u8) -> Bytes {
            let (mut start, end) = match metadata_range(_metadata.clone(), _index) {
                Result::Ok((start, end)) => (start, end),
                Result::Err(_) => (0, 0)
            };
            let mut bytes_array = BytesTrait::new(496, array![]);
            loop {
                if ((end - start) <= 16) {
                    let (_, res) = _metadata.read_u128_packed(start, end - start);
                    bytes_array.append_u128(res);
                    break ();
                }
                let (_, res) = _metadata.read_u128_packed(start, BYTES_PER_ELEMENT.into());
                bytes_array.append_u128(res);
                start = start + BYTES_PER_ELEMENT.into()
            };
            bytes_array
        }
        fn has_metadata(_metadata: Bytes, _index: u8) -> bool {
            match metadata_range(_metadata, _index) {
                Result::Ok((_, _)) => true,
                Result::Err(_) => false
            }
        }
    }

    fn metadata_range(_metadata: Bytes, _index: u8) -> Result<(u32, u32), u8> {
        let start = _index.into() * RANGE_SIZE * 2;
        let mid = start + RANGE_SIZE;
        let (_, mid_metadata) = _metadata.read_u32(mid.into());
        let (_, start_metadata) = _metadata.read_u32(start.into());
        Result::Ok((start_metadata, mid_metadata))
    }
}


#[cfg(test)]
mod tets {
    use alexandria_bytes::{Bytes, BytesTrait};
    use super::aggregation_ism_metadata::AggregationIsmMetadata;

    #[test]
    fn test_aggregation_ism_metadata() {
        let encoded_metadata = BytesTrait::new(
            64,
            array![
                0x0000001800000024000000240000002C,
                0x0000002C00000034AAAAAAAAAAAAAAAA,
                0xBBBBCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
                0x00000000000000000000000000000000
            ]
        );
        let mut expected_result = array![
            0xAAAAAAAAAAAAAAAABBBBCCCC_u256, 0xDDDDDDDDEEEEEEEE_u256, 0xFFFFFFFF00000000_u256
        ];
        let mut cur_idx = 0;
        loop {
            if (cur_idx == 3) {
                break ();
            }
            let result = AggregationIsmMetadata::metadata_at(encoded_metadata.clone(), cur_idx);
            assert(
                *BytesTrait::data(result.clone())[0] == *expected_result.at(cur_idx.into()).low,
                'Agg metadata extract failed'
            );
            cur_idx += 1;
        };
    }
}
