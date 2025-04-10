pub mod aggregation_ism_metadata {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::result::Result;

    pub trait AggregationIsmMetadata {
        fn metadata_at(_metadata: @Bytes, _index: u8) -> Bytes;
        fn has_metadata(_metadata: @Bytes, _index: u8) -> bool;
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
        fn metadata_at(_metadata: @Bytes, _index: u8) -> Bytes {
            let (mut start, end) = match metadata_range(_metadata, _index) {
                Result::Ok((start, end)) => (start, end),
                Result::Err(_) => (0, 0),
            };
            let (_, res) = _metadata.read_bytes(start, end - start);
            res
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
        fn has_metadata(_metadata: @Bytes, _index: u8) -> bool {
            match metadata_range(_metadata, _index) {
                Result::Ok((start, _)) => start > 0,
                Result::Err(_) => false,
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
    /// Result<u32, u32), u8> -  Result on whether or not metadata was provided for the ISM at
    /// `_index`
    fn metadata_range(_metadata: @Bytes, _index: u8) -> Result<(u32, u32), u8> {
        let start = _index.into() * RANGE_SIZE * 2;
        let mid = start + RANGE_SIZE;
        let (_, mid_metadata) = _metadata.read_u32(mid.into());
        let (_, start_metadata) = _metadata.read_u32(start.into());
        Result::Ok((start_metadata, mid_metadata))
    }
}


#[cfg(test)]
mod test {
    use alexandria_bytes::BytesTrait;
    use super::aggregation_ism_metadata::AggregationIsmMetadata;

    #[test]
    fn test_aggregation_ism_metadata() {
        let encoded_metadata = BytesTrait::new(
            64,
            array![
                0x0000001800000024000000240000002C,
                0x0000002C00000034AAAAAAAAAAAAAAAA,
                0xBBBBCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
                0x00000000000000000000000000000000,
            ],
        );
        let mut expected_result = array![0xAAAAAAAAAAAAAAAABBBBCCCC00000000_u256];
        let mut cur_idx = 0;
        while (cur_idx != 1) {
            let result = AggregationIsmMetadata::metadata_at(@encoded_metadata, 0);
            assert(
                *BytesTrait::data(result.clone())[0] == *expected_result.at(cur_idx).low,
                'Agg metadata extract failed',
            );
            cur_idx += 1;
        };
    }

    #[test]
    fn test_metadata_not_padded() {
        let encoded_metadata = BytesTrait::new(
            141,
            array![
                0x000000080000008d071e1b5e54086bbd,
                0xe2b7a131a2c913f442485974c32df56e,
                0xe47f9456b3270daebe22faba5bc0223a,
                0x7e3077adcd04391f2ccdd2b2ad2eac2d,
                0x71c3f04755d5d95d000000015dcbf07f,
                0xa1898b0d8b64991f099e8478268fb36e,
                0x0e5fe7832aa345da8b8888645622786d,
                0x53d898c95d75d37a582de78deda23497,
                0x7d806349eac6653e9190d11a1c,
            ],
        );
        let mut expected_result = array![
            0x071E1B5E54086BBDE2B7A131A2C913F4_u256,
            0x42485974C32DF56EE47F9456B3270DAE_u256,
            0xbe22faba5bc0223a7e3077adcd04391f_u256,
            0x2ccdd2b2ad2eac2d71c3f04755d5d95d_u256,
            0x000000015dcbf07fa1898b0d8b64991f_u256,
            0x099e8478268fb36e0e5fe7832aa345da_u256,
            0x8B8888645622786D53D898C95D75D37A_u256,
            0x582DE78DEDA234970000007D806349EA_u256,
            0xC6653E91900000000000000000000000_u256,
        ];
        let result = AggregationIsmMetadata::metadata_at(@encoded_metadata, 0);

        let mut cur_idx = 0;
        while (cur_idx != 9) {
            assert(
                *BytesTrait::data(result.clone())[cur_idx] == *expected_result.at(cur_idx).low,
                'Agg metadata extract failed',
            );
            cur_idx += 1;
        }
    }

    #[test]
    fn test_aggregation_ism_has_metadata() {
        let encoded_metadata = BytesTrait::new(
            64,
            array![
                0x00000018000000240000000000000000,
                0x0000002C00000034AAAAAAAAAAAAAAAA,
                0xBBBBCCCCDDDDDDDDEEEEEEEEFFFFFFFF,
                0x00000000000000000000000000000000,
            ],
        );
        assert_eq!(AggregationIsmMetadata::has_metadata(@encoded_metadata, 0), true);
        assert_eq!(AggregationIsmMetadata::has_metadata(@encoded_metadata, 1), false);
    }
}
