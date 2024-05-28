#[starknet::contract]
pub mod noop_ism {
    use alexandria_bytes::Bytes;
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait
    };
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IInterchainSecurityModuleImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::NULL(())
        }

        fn verify(self: @ContractState,_metadata: Bytes, _message: Message) -> bool {
            true
        }

    }
}
