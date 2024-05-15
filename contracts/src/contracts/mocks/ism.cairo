#[starknet::contract]
pub mod ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, ModuleType
    };
    use starknet::ContractAddress;
    use starknet::EthAddress;

    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl IMessageidMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MESSAGE_ID_MULTISIG(starknet::get_contract_address())
        }

        fn verify(self: @ContractState, _metadata: Bytes, _message: Message,) -> bool {
            true
        }

        fn validators_and_threshold(
            self: @ContractState, _message: Message
        ) -> (Span<EthAddress>, u32) {
            (array![].span(), 0)
        }

        fn get_validators(self: @ContractState) -> Span<EthAddress> {
            array![].span()
        }

        fn get_threshold(self: @ContractState) -> u32 {
            0
        }

        fn set_validators(ref self: ContractState, _validators: Span<EthAddress>) {}

        fn set_threshold(ref self: ContractState, _threshold: u32) {}
    }
}
