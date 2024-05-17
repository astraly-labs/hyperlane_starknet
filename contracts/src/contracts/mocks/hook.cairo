#[starknet::contract]
pub mod hook {
    use hyperlane_starknet::interfaces::{IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait, Types};
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};


    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn get_hook_type(self: @ContractState) -> Types {
            Types::UNUSED(())
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool{
            true
        }

        fn post_dispatch(ref self: ContractState, _metadata: Bytes, _message: u256){}
    
        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: u256) -> u256{
            0_u256
        }
    }
}