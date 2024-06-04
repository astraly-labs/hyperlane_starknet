pub mod standard_hook_metadata {

    use starknet::ContractAddress;
    use alexandria_bytes::{Bytes, BytesTrait};
    struct Metadata {
        variant: u16,
        msg_value: u256, 
        gas_limit: u256, 
        refund_address :ContractAddress
    }

    const VARIANT_OFFSET : u8= 0;
    const MSG_VALUE_OFFSET : u8= 2;
    const GAS_LIMIT_OFFSET : u8= 34;
    const REFUND_ADDRESS_OFFSET : u8= 66;
    const MIN_METADATA_LENGTH: u256 = 86;

    pub const VARIANT : u8= 1;

    #[generate_trait]
    pub impl StandardHookMetadataImpl of StandardHookMetadata {
        fn variant(_metadata: Bytes) -> u16 {
            if (_metadata.size() < VARIANT_OFFSET.into() +2) {
                return 0;
            }
            let (_, res) = _metadata.read_u16(VARIANT_OFFSET.into());
            res
        }

        fn msg_value(_metadata: Bytes, _default: u256) -> u256 {
            if (_metadata.size() < MSG_VALUE_OFFSET.into() +32) {
                return _default;
            }
            let (_, res) = _metadata.read_u256(MSG_VALUE_OFFSET.into());
            res
        }

        fn gas_limit(_metadata: Bytes, _default: u256) -> u256 {
            if (_metadata.size() < GAS_LIMIT_OFFSET.into() +32) {
                return _default;
            }
            let (_, res) = _metadata.read_u256(GAS_LIMIT_OFFSET.into());
            res
        }

        fn refund_address(_metadata: Bytes, _default: ContractAddress) -> ContractAddress {
            if (_metadata.size() < REFUND_ADDRESS_OFFSET.into() +32) {
                return _default;
            }
            let (_, res) = _metadata.read_address(REFUND_ADDRESS_OFFSET.into());
            res
        }

        fn get_custom_metadata(_metadata: Bytes) -> Bytes {
            if (_metadata.size().into() < MIN_METADATA_LENGTH) {
                return BytesTrait::new(0,array![]);
            }
            let (_, res) = _metadata.read_bytes(MIN_METADATA_LENGTH.try_into().unwrap(), _metadata.size());
            res
        }
    }
}