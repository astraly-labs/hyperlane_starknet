use alexandria_bytes::Bytes;
use contracts::libs::message::Message;

#[starknet::interface]
pub trait ITestPostDispatchHook<TContractState> {
    fn hook_type(self: @TContractState) -> u8;
    fn supports_metadata(self: @TContractState, _metadata: Bytes) -> bool;
    fn set_fee(ref self: TContractState, fee: u256);
    fn message_dispatched(self: @TContractState, message_id: u256) -> bool;
    fn post_dispatch(ref self: TContractState, metadata: Bytes, message: Message);
    fn quote_dispatch(ref self: TContractState, metadata: Bytes, message: Message) -> u256;
}

#[starknet::contract]
pub mod TestPostDispatchHook {
    use alexandria_bytes::{Bytes, BytesTrait};
    use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::{
        StandardHookMetadata, VARIANT,
    };
    use contracts::libs::message::{Message, MessageTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    #[storage]
    struct Storage {
        fee: u256,
        message_dispatched: Map<u256, bool>,
    }

    pub mod Errors {
        pub const INVALID_METADATA_VARIANT: felt252 = 'Invalid metadata variant';
    }

    #[abi(embed_v0)]
    impl TestPostDispatchHookImpl of super::ITestPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> u8 {
            0
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            _metadata.size() == 0 || StandardHookMetadata::variant(_metadata) == VARIANT.into()
        }

        fn set_fee(ref self: ContractState, fee: u256) {
            self.fee.write(fee);
        }

        fn message_dispatched(self: @ContractState, message_id: u256) -> bool {
            self.message_dispatched.read(message_id)
        }

        fn post_dispatch(ref self: ContractState, metadata: Bytes, message: Message) {
            assert(self.supports_metadata(metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            let (hash, _) = MessageTrait::format_message(message);
            self.message_dispatched.write(hash, true);
        }

        fn quote_dispatch(ref self: ContractState, metadata: Bytes, message: Message) -> u256 {
            assert(self.supports_metadata(metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            self.fee.read()
        }
    }
}
