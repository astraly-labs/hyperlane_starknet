#[starknet::contract]
pub mod domain_routing_hook {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl
    };
    use hyperlane_starknet::contracts::client::{mailboxclient};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{
        IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait,
        DomainRoutingHookConfig, IDomainRoutingHook, Types
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ContractAddress, contract_address_const};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        hooks: LegacyMap<u32, IPostDispatchHookDispatcher>,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }


    mod Errors {
        pub const INVALID_DESTINATION: felt252 = 'Destination has no hooks';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        MailboxclientEvent: MailboxclientComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox: ContractAddress, _owner: ContractAddress) {
        self.mailboxclient.initialize(_mailbox);
        self.ownable.initializer(_owner);
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> Types {
            Types::ROUTING(())
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            true
        }

        fn post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {
            self._get_configured_hook(_message.clone()).post_dispatch(_metadata, _message);
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            self._get_configured_hook(_message.clone()).quote_dispatch(_metadata, _message)
        }
    }

    #[abi(embed_v0)]
    impl IDomainRoutingHookImpl of IDomainRoutingHook<ContractState> {
        fn setHook(ref self: ContractState, _destination: u32, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.hooks.write(_destination, IPostDispatchHookDispatcher { contract_address: _hook });
        }
        fn setHooks(ref self: ContractState, configs: Array<DomainRoutingHookConfig>) {
            self.ownable.assert_only_owner();
            let mut configs_span = configs.span();
            loop {
                match configs_span.pop_front() {
                    Option::Some(config) => { self.setHook(*config.destination, *config.hook) },
                    Option::None(_) => { break; },
                };
            };
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_configured_hook(
            ref self: ContractState, _message: Message
        ) -> IPostDispatchHookDispatcher {
            let dispatcher_instance = self.hooks.read(_message.destination);
            assert(
                dispatcher_instance.contract_address != contract_address_const::<0>(),
                Errors::INVALID_DESTINATION
            );
            dispatcher_instance
        }
    }
}
