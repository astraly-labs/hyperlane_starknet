#[starknet::contract]
pub mod hook {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{
        IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait, Types
    };


    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            true
        }

        fn post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {}

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            0_u256
        }
    }
}
