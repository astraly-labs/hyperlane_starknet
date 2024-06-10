pub mod standard_hook_metadata {
    use alexandria_bytes::{Bytes, BytesTrait};

    use starknet::ContractAddress;
    struct Metadata {
        variant: u16,
        msg_value: u256,
        gas_limit: u256,
        refund_address: ContractAddress
    }

    const VARIANT_OFFSET: u8 = 0;
    const MSG_VALUE_OFFSET: u8 = 2;
    const GAS_LIMIT_OFFSET: u8 = 34;
    const REFUND_ADDRESS_OFFSET: u8 = 66;
    const MIN_METADATA_LENGTH: u256 = 98;

    pub const VARIANT: u8 = 1;

    #[generate_trait]
    pub impl StandardHookMetadataImpl of StandardHookMetadata {
        fn variant(_metadata: Bytes) -> u16 {
            if (_metadata.size() < VARIANT_OFFSET.into() + 2) {
                return 0;
            }
            let (_, res) = _metadata.read_u16(VARIANT_OFFSET.into());
            res
        }

        fn msg_value(_metadata: Bytes, _default: u256) -> u256 {
            if (_metadata.size() < MSG_VALUE_OFFSET.into() + 32) {
                return _default;
            }
            let (_, res) = _metadata.read_u256(MSG_VALUE_OFFSET.into());
            res
        }

        fn gas_limit(_metadata: Bytes, _default: u256) -> u256 {
            if (_metadata.size() < GAS_LIMIT_OFFSET.into() + 32) {
                return _default;
            }
            let (_, res) = _metadata.read_u256(GAS_LIMIT_OFFSET.into());
            res
        }

        fn refund_address(_metadata: Bytes, _default: ContractAddress) -> ContractAddress {
            if (_metadata.size() < REFUND_ADDRESS_OFFSET.into() + 32) {
                return _default;
            }
            let (_, res) = _metadata.read_address(REFUND_ADDRESS_OFFSET.into());
            res
        }

        fn get_custom_metadata(_metadata: Bytes) -> Bytes {
            if (_metadata.size().into() < MIN_METADATA_LENGTH) {
                return BytesTrait::new_empty();
            }
            let (_, res) = _metadata
                .read_bytes(
                    MIN_METADATA_LENGTH.try_into().unwrap(),
                    _metadata.size() - MIN_METADATA_LENGTH.try_into().unwrap()
                );
            res
        }
    }
}


#[cfg(test)]
mod tests {
    use alexandria_bytes::{Bytes, BytesTrait};
    use starknet::{ContractAddress, contract_address_const};
    use super::standard_hook_metadata::StandardHookMetadata;
    #[test]
    fn test_standard_hook_metadata_default_value() {
        let mut metadata = BytesTrait::new_empty();
        assert_eq!(0, StandardHookMetadata::variant(metadata.clone()));
        let variant = 1;
        metadata.append_u16(variant);
        assert_eq!(123, StandardHookMetadata::msg_value(metadata.clone(), 123));
        let msg_value = 0x123123123;
        metadata.append_u256(msg_value);
        assert_eq!(4567, StandardHookMetadata::gas_limit(metadata.clone(), 4567));
        let gas_limit = 0x456456456;
        metadata.append_u256(gas_limit);
        let other_refunded_address = 'other_refunded'.try_into().unwrap();
        assert_eq!(
            other_refunded_address,
            StandardHookMetadata::refund_address(metadata.clone(), other_refunded_address)
        );
        let refund_address: ContractAddress = 'refund_address'.try_into().unwrap();
        metadata.append_address(refund_address);
    }

    #[test]
    fn test_standard_hook_metadata() {
        let mut metadata = BytesTrait::new_empty();
        let variant = 1;
        let msg_value = 0x123123123;
        let gas_limit = 0x456456456;
        let refund_address: ContractAddress = 'refund_address'.try_into().unwrap();
        let custom_metadata = array![0x123123123123, 0x123123123];
        metadata.append_u16(variant);
        metadata.append_u256(msg_value);
        metadata.append_u256(gas_limit);
        metadata.append_address(refund_address);
        metadata.append_u256(*custom_metadata.at(0));
        metadata.append_u256(*custom_metadata.at(1));
        let mut expected_custom_metadata = BytesTrait::new_empty();
        expected_custom_metadata.append_u256(*custom_metadata.at(0));
        expected_custom_metadata.append_u256(*custom_metadata.at(1));
        assert_eq!(variant, StandardHookMetadata::variant(metadata.clone()));
        assert_eq!(msg_value, StandardHookMetadata::msg_value(metadata.clone(), 0));
        assert_eq!(gas_limit, StandardHookMetadata::gas_limit(metadata.clone(), 0));
        assert_eq!(
            refund_address,
            StandardHookMetadata::refund_address(metadata.clone(), contract_address_const::<0>())
        );
        assert(
            expected_custom_metadata == StandardHookMetadata::get_custom_metadata(metadata.clone()),
            'SHM: custom metadata mismatch'
        );
    }
}
