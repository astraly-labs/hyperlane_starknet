#[starknet::interface]
pub trait IMockHook<T> {
    fn set_quote_dispatch(ref self: T, _value: u256);
    fn get_post_dispatch_calls(self: @T) -> u8;
    fn get_quote_dispatch_calls(self: @T) -> u8;
}

#[starknet::contract]
pub mod hook {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{
        IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait, Types
    };
    use super::IMockHook;

    #[storage]
    struct Storage {
        quote_value: u256,
        post_dispatch_calls: u8,
        quote_dispatch_calls: u8,
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> Types {
            Types::UNUSED(())
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            true
        }

        fn post_dispatch(
            ref self: ContractState, _metadata: Bytes, _message: Message, _fee_amount: u256
        ) {
            self.post_dispatch_calls.write(self.post_dispatch_calls.read() + 1);
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            self.quote_dispatch_calls.write(self.quote_dispatch_calls.read() + 1);
            self.quote_value.read()
        }
    }

    #[abi(embed_v0)]
    impl IMockHookImpl of IMockHook<ContractState> {
        fn set_quote_dispatch(ref self: ContractState, _value: u256) {
            self.quote_value.write(_value);
        }

        fn get_post_dispatch_calls(self: @ContractState) -> u8 {
            self.post_dispatch_calls.read()
        }

        fn get_quote_dispatch_calls(self: @ContractState) -> u8 {
            self.quote_dispatch_calls.read()
        }
    }
}
