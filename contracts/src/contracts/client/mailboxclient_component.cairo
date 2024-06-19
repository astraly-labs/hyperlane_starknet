#[starknet::component]
pub mod MailboxclientComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::interfaces::{
        IMailboxClient, IMailboxDispatcher, IMailboxDispatcherTrait
    };
    use openzeppelin::access::ownable::{OwnableComponent, OwnableComponent::InternalImpl};
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ContractAddress, contract_address_const};

    #[storage]
    struct Storage {
        mailbox: IMailboxDispatcher,
        local_domain: u32,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
    }

    pub mod Errors {
        pub const ADDRESS_CANNOT_BE_ZERO: felt252 = 'Address cannot be zero';
    }


    #[embeddable_as(MailboxClientImpl)]
    impl MailboxClient<
        TContractState,
        +HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>
    > of IMailboxClient<ComponentState<TContractState>> {
        fn set_hook(ref self: ComponentState<TContractState>, _hook: ContractAddress) {
            let ownable_comp = get_dep_component!(@self, Owner);
            ownable_comp.assert_only_owner();
            assert(_hook != contract_address_const::<0>(), Errors::ADDRESS_CANNOT_BE_ZERO);
            self.hook.write(_hook);
        }

        fn set_interchain_security_module(
            ref self: ComponentState<TContractState>, _module: ContractAddress
        ) {
            let ownable_comp = get_dep_component!(@self, Owner);
            ownable_comp.assert_only_owner();
            assert(_module != contract_address_const::<0>(), Errors::ADDRESS_CANNOT_BE_ZERO);
            self.interchain_security_module.write(_module);
        }

        fn get_local_domain(self: @ComponentState<TContractState>) -> u32 {
            self.mailbox.read().get_local_domain()
        }

        fn get_hook(self: @ComponentState<TContractState>) -> ContractAddress {
            self.hook.read()
        }

        fn get_interchain_security_module(
            self: @ComponentState<TContractState>
        ) -> ContractAddress {
            self.interchain_security_module.read()
        }


        fn _MailboxClient_initialize(
            ref self: ComponentState<TContractState>,
            _hook: ContractAddress,
            _interchain_security_module: ContractAddress,
        ) {
            let ownable_comp = get_dep_component!(@self, Owner);
            ownable_comp.assert_only_owner();
            self.set_hook(_hook);
            self.set_interchain_security_module(_interchain_security_module);
        }

        fn _is_latest_dispatched(self: @ComponentState<TContractState>, _id: u256) -> bool {
            self.mailbox.read().get_latest_dispatched_id() == _id
        }

        fn _is_delivered(self: @ComponentState<TContractState>, _id: u256) -> bool {
            self.mailbox.read().delivered(_id)
        }

        fn mailbox(self: @ComponentState<TContractState>) -> ContractAddress {
            let mailbox: IMailboxDispatcher = self.mailbox.read();
            mailbox.contract_address
        }

        fn _dispatch(
            self: @ComponentState<TContractState>,
            _destination_domain: u32,
            _recipient: ContractAddress,
            _message_body: Bytes,
            _hook_metadata: Option<Bytes>,
            _hook: Option<ContractAddress>
        ) -> u256 {
            self
                .mailbox
                .read()
                .dispatch(_destination_domain, _recipient, _message_body, _hook_metadata, _hook)
        }

        fn quote_dispatch(
            self: @ComponentState<TContractState>,
            _destination_domain: u32,
            _recipient: ContractAddress,
            _message_body: Bytes,
            _hook_metadata: Option<Bytes>,
            _hook: Option<ContractAddress>
        ) -> u256 {
            self
                .mailbox
                .read()
                .quote_dispatch(
                    _destination_domain, _recipient, _message_body, _hook_metadata, _hook
                )
        }
    }

    #[generate_trait]
    pub impl MailboxClientInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, _mailbox: ContractAddress) {
            let mailbox = IMailboxDispatcher { contract_address: _mailbox };
            self.mailbox.write(mailbox);
            self.local_domain.write(mailbox.get_local_domain());
        }
    }
}
