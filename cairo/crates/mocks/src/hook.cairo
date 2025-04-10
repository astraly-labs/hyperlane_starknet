#[starknet::contract]
pub mod hook {
    use alexandria_bytes::{Bytes, BytesStore};
    use contracts::interfaces::{
        IPostDispatchHook, Types,
    };
    use contracts::libs::message::Message;
    use contracts::utils::utils::{SerdeSnapshotBytes, SerdeSnapshotMessage};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> Types {
            Types::UNUSED(())
        }

        fn supports_metadata(self: @ContractState, _metadata: @Bytes) -> bool {
            true
        }

        fn post_dispatch(
            ref self: ContractState, _metadata: @Bytes, _message: @Message, _fee_amount: u256,
        ) {}

        fn quote_dispatch(ref self: ContractState, _metadata: @Bytes, _message: @Message) -> u256 {
            0_u256
        }
    }
}
