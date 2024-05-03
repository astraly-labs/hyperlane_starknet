#[starknet::contract]
mod mailboxclient {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::interfaces::{
        IMailbox, IMailboxDispatcher, IMailboxDispatcherTrait, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, IMailboxClient,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ContractAddress, contract_address_const, ClassHash};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        mailbox: ContractAddress,
        local_domain: u32,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }


    #[constructor]
    fn constructor(ref self: ContractState, _mailbox: ContractAddress, _owner: ContractAddress) {
        self.mailbox.write(_mailbox);
        let mailbox = IMailboxDispatcher { contract_address: _mailbox };
        let local_domain = mailbox.get_local_domain();
        self.local_domain.write(local_domain);
        self.ownable.initializer(_owner);
    }
    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl IMailboxClientImpl of IMailboxClient<ContractState> {
        fn set_hook(ref self: ContractState, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.hook.write(_hook);
        }

        fn set_interchain_security_module(ref self: ContractState, _module: ContractAddress) {
            self.ownable.assert_only_owner();
            self.interchain_security_module.write(_module);
        }

        fn _MailboxClient_initialize(
            ref self: ContractState,
            _hook: ContractAddress,
            _interchain_security_module: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self.set_hook(_hook);
            self.set_interchain_security_module(_interchain_security_module);
        }

        fn _is_latest_dispatched(self: @ContractState, _id: u256) -> bool {
            let mailbox_address = self.mailbox.read();
            let mailbox = IMailboxDispatcher { contract_address: mailbox_address };
            mailbox.get_latest_dispatched_id() == _id
        }

        fn _is_delivered(self: @ContractState, _id: u256) -> bool {
            let mailbox_address = self.mailbox.read();
            let mailbox = IMailboxDispatcher { contract_address: mailbox_address };
            mailbox.delivered(_id)
        }

        fn _dispatch(
            self: @ContractState,
            _destination_domain: u32,
            _recipient: ContractAddress,
            _message_body: Bytes,
            _hook_metadata: Option<Bytes>,
            _hook: Option<ContractAddress>
        ) -> u256 {
            let mailbox_address = self.mailbox.read();
            let mailbox = IMailboxDispatcher { contract_address: mailbox_address };
            mailbox.dispatch(_destination_domain, _recipient, _message_body, _hook_metadata, _hook)
        }

        fn quote_dispatch(
            self: @ContractState,
            _destination_domain: u32,
            _recipient: ContractAddress,
            _message_body: Bytes,
            _hook_metadata: Option<Bytes>,
            _hook: Option<ContractAddress>
        ) -> u256 {
            let mailbox_address = self.mailbox.read();
            let mailbox = IMailboxDispatcher { contract_address: mailbox_address };
            mailbox
                .quote_dispatch(
                    _destination_domain, _recipient, _message_body, _hook_metadata, _hook
                )
        }
    }
}
