#[starknet::contract]
pub mod ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, ModuleType
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl IMessageidMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MESSAGE_ID_MULTISIG(starknet::get_contract_address())
        }

        fn verify(
            self: @ContractState,
            _metadata: Bytes,
            _message: Message,
            _validator_configuration: ContractAddress
        ) -> bool {
            true
        }
    }
}
