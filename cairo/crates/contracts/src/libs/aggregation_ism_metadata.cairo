pub mod aggregation_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::result::{ResultTrait, Result};

    pub trait AggregationIsmMetadata {
        fn metadata_at(_metadata: Bytes, _index: u8) -> Bytes;
        fn has_metadata(_metadata: Bytes, _index: u8) -> bool;
    }
    /// * Format of metadata:
    /// *
    /// * [????:????] Metadata start/end uint32 ranges, packed as uint64
    /// * [????:????] ISM metadata, packed encoding
    /// *
    const RANGE_SIZE: u8 = 4;
    const BYTES_PER_ELEMENT: u8 = 16;

    impl AggregationIsmMetadataImpl of AggregationIsmMetadata {
        /// Returns the metadata provided for the ISM at `_index`
        /// Dev: Callers must ensure _index is less than the number of metadatas provided
        /// Dev: Callers must ensure `hasMetadata(_metadata, _index)`
        /// 
        /// # Arguments
        ///
        /// * - `_metadata` -Encoded Aggregation ISM metadata
        /// * - `_index` - The index of the ISM to check for metadata for
        /// 
        /// # Returns
        /// 
        /// Bytes -  The metadata provided for the ISM at `_index`
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
        /// Returns whether or not metadata was provided for the ISM at _index
        /// Dev: Callers must ensure _index is less than the number of metadatas provided
        /// 
        /// # Arguments
        ///
        /// * - `_metadata` -Encoded Aggregation ISM metadata
        /// * - `_index` - The index of the ISM to check for metadata for
        /// 
        /// # Returns
        /// 
        /// boolean -  Whether or not metadata was provided for the ISM at `_index`
        fn has_metadata(_metadata: Bytes, _index: u8) -> bool {
            match metadata_range(_metadata, _index) {
                Result::Ok((start, _)) => start > 0,
                Result::Err(_) => false
            }
        }
    }

    /// Returns the range of the metadata provided for the ISM at _index
    /// Dev: Callers must ensure _index is less than the number of metadatas provided
    /// 
    /// # Arguments
    ///
    /// * - `_metadata` -Encoded Aggregation ISM metadata
    /// * - `_index` - The index of the ISM to check for metadata for
    /// 
    /// # Returns
    /// 
    /// Result<u32, u32), u8> -  Result on whether or not metadata was provided for the ISM at `_index`
    pub fn metadata_range(_metadata: Bytes, _index: u8) -> Result<(u32, u32), u8> {
        let start = _index.into() * RANGE_SIZE * 2;
        let mid = start + RANGE_SIZE;
        let (_, mid_metadata) = _metadata.read_u32(mid.into());
        let (_, start_metadata) = _metadata.read_u32(start.into());
        Result::Ok((start_metadata, mid_metadata))
    }
}


#[cfg(test)]
mod test {
    use alexandria_bytes::{Bytes, BytesTrait};
    use super::aggregation_ism_metadata::AggregationIsmMetadata;
    use super::aggregation_ism_metadata::metadata_range;

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

    #[test]
    fn test_aggregation_ism_has_metadata() {
        let encoded_metadata = BytesTrait::new(
            64,
            array![
                0x00000018000000240000000000000000,
                0x0000002C00000034AAAAAAAAAAAAAAAA,
                0xBBBBCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
                0x00000000000000000000000000000000
            ]
        );
        assert_eq!(AggregationIsmMetadata::has_metadata(encoded_metadata.clone(), 0), true);
        assert_eq!(AggregationIsmMetadata::has_metadata(encoded_metadata.clone(), 1), false);
    }

    #[test]
    fn test_aggregation_ism_has_metadata_AAAAAA() {
        // [0, 0, 0, 8, 0, 0, 0, 141, 2, 208, 163, 69, 107, 221, 59, 254, 40, 70, 127, 194, 111, 32, 204, 20, 18, 20, 209, 155, 139, 86, 30, 88, 163, 203, 80, 220, 252, 62, 47, 89, 96, 10, 30, 139, 66, 77, 14, 202, 134, 71, 249, 116, 168, 30, 154, 126, 218, 21, 254, 36, 192, 54, 134, 161, 61, 239, 108, 253, 29, 163, 201, 6, 0, 0, 0, 1, 16, 18, 191, 214, 79, 225, 104, 10, 19, 102, 207, 66, 65, 202, 41, 104, 182, 123, 85, 239, 151, 152, 184, 11, 55, 105, 94, 146, 222, 178, 93, 114, 124, 165, 40, 180, 54, 7, 44, 5, 178, 246, 155, 65, 138, 155, 165, 133, 80, 254, 172, 234, 18, 209, 109, 2, 63, 109, 60, 104, 49, 52, 196, 102, 28]
        let encoded_metadata = BytesTrait::new(
            64,
            array![
                0x000000080000008d02d0a3456bdd3bfe,
                0x28467fc26f20cc141214d19b8b561e58,
                0xa3cb50dcfc3e2f59600a1e8b424d0eca,
                0x8647f974a81e9a7eda15fe24c03686a1
            ]
        );
        assert_eq!(AggregationIsmMetadata::has_metadata(encoded_metadata.clone(), 0), true);
        assert_eq!(AggregationIsmMetadata::has_metadata(encoded_metadata.clone(), 1), false);
        // let result = AggregationIsmMetadata::metadata_at(encoded_metadata.clone(), 0);
        // println!("result: {:?}", result.unwrap());
        let range = metadata_range(encoded_metadata.clone(), 0);
        let (start, end): (u32, u32) = range.unwrap();
        println!("start: {:?}", start);
        println!("end: {:?}", end);
    }
}
