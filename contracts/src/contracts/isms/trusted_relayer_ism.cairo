#[starknet::contract]
pub mod trusted_relayer_ism {
    use alexandria_bytes::Bytes;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, IMailboxDispatcher, IMailboxDispatcherTrait,
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        mailbox: ContractAddress, 
        trusted_relayer: ContractAddress,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, _mailbox: ContractAddress, _trusted_relayer: ContractAddress) {
        self.mailbox.write(_mailbox);
        self.trusted_relayer.write(_trusted_relayer);
    }
    #[abi(embed_v0)]
    impl IInterchainSecurityModuleImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::NULL(())
        }

        fn verify(self: @ContractState,_metadata: Bytes, _message: Message) -> bool {
            let mailbox = IMailboxDispatcher {contract_address: self.mailbox.read()};
            let (id, _) = MessageTrait::format_message(_message);
            mailbox.processor(id) == self.trusted_relayer.read()
        }

    }
}
