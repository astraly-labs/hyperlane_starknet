use alexandria_bytes::Bytes;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IRouter<TState> {
    fn enroll_remote_router(ref self: TState, domain: u32, router: u256);
    fn enroll_remote_routers(ref self: TState, domains: Array<u32>, addresses: Array<u256>);
    fn unenroll_remote_router(ref self: TState, domain: u32);
    fn unenroll_remote_routers(ref self: TState, domains: Array<u32>);
    fn handle(ref self: TState, origin: u32, sender: u256, message: Bytes);
    fn domains(self: @TState) -> Array<u32>;
    fn routers(self: @TState, domain: u32) -> u256;
}

#[starknet::component]
pub mod RouterComponent {
    use alexandria_bytes::Bytes;
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl
    };
    use hyperlane_starknet::contracts::libs::enumerable_map::{EnumerableMap, EnumerableMapTrait};
    use hyperlane_starknet::interfaces::{
        IMailboxClient, IMailboxDispatcher, IMailboxDispatcherTrait
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as OwnableInternalImpl
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        routers: EnumerableMap<u32, u256>,
        gas_router: ContractAddress,
    }

    mod Err {
        pub fn domain_not_found(domain: u32) {
            panic!("No router enrolled for domain {}", domain);
        }
    }

    pub trait IMessageRecipientInternalHookTrait<TContractState> {
        fn _handle(
            ref self: ComponentState<TContractState>, origin: u32, sender: u256, message: Bytes
        );
    }

    #[embeddable_as(RouterImpl)]
    impl Router<
        TContractState,
        +HasComponent<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Hook: IMessageRecipientInternalHookTrait<TContractState>
    > of super::IRouter<ComponentState<TContractState>> {
        fn enroll_remote_router(
            ref self: ComponentState<TContractState>, domain: u32, router: u256
        ) {
            let ownable_comp = get_dep_component!(@self, Owner);
            ownable_comp.assert_only_owner();
            self._enroll_remote_router(domain, router);
        }

        fn enroll_remote_routers(
            ref self: ComponentState<TContractState>, domains: Array<u32>, addresses: Array<u256>
        ) {
            let ownable_comp = get_dep_component!(@self, Owner);
            ownable_comp.assert_only_owner();

            let domains_len = domains.len();
            if addresses.len() != domains_len {
                panic!("Addresses array length must match domains array length");
            }

            let mut i = 0;
            while i < domains_len {
                self._enroll_remote_router(*domains.at(i), *addresses.at(i));
                i += 1;
            }
        }

        fn unenroll_remote_router(ref self: ComponentState<TContractState>, domain: u32) {
            let mut ownable_comp = get_dep_component_mut!(ref self, Owner);
            ownable_comp.assert_only_owner();

            self._unenroll_remote_router(domain);
        }

        fn unenroll_remote_routers(ref self: ComponentState<TContractState>, domains: Array<u32>,) {
            let domains_len = domains.len();
            let mut i = 0;
            while i < domains_len {
                self._unenroll_remote_router(*domains.at(i));
                i += 1;
            }
        }

        fn handle(
            ref self: ComponentState<TContractState>, origin: u32, sender: u256, message: Bytes
        ) {
            let router = self._must_have_remote_router(origin);
            assert!(router == sender, "Enrolled router does not match sender");

            Hook::_handle(ref self, origin, sender, message);
        }

        fn domains(self: @ComponentState<TContractState>) -> Array<u32> {
            self.routers.read().keys()
        }

        fn routers(self: @ComponentState<TContractState>, domain: u32) -> u256 {
            self.routers.read().get(domain)
        }
    }

    #[generate_trait]
    pub impl RouterComponentInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _enroll_remote_router(
            ref self: ComponentState<TContractState>, domain: u32, address: u256
        ) {
            let mut routers = self.routers.read();
            let _ = routers.set(domain, address);
        }

        fn _unenroll_remote_router(ref self: ComponentState<TContractState>, domain: u32) {
            let mut routers = self.routers.read();
            routers.remove(domain);
        }

        fn _is_remote_router(
            self: @ComponentState<TContractState>, domain: u32, address: u256
        ) -> bool {
            let routers = self.routers.read();
            let router = routers.get(domain);
            router == address
        }

        fn _must_have_remote_router(self: @ComponentState<TContractState>, domain: u32) -> u256 {
            let routers = self.routers.read();
            let router = routers.get(domain);

            if router == 0 {
                Err::domain_not_found(domain);
            }

            router
        }

        fn _Router_dispatch(
            self: @ComponentState<TContractState>,
            destination_domain: u32,
            value: u256,
            message_body: Bytes,
            hook_metadata: Bytes,
            hook: ContractAddress
        ) -> u256 {
            let router = self._must_have_remote_router(destination_domain);
            let mut mailbox_comp = get_dep_component!(self, MailBoxClient);
            let value = mailbox_comp
                .mailbox
                .read()
                .dispatch(
                    destination_domain,
                    router,
                    message_body,
                    value,
                    Option::Some(hook_metadata),
                    Option::Some(hook),
                );
            value
        }

        fn _Router_quote_dispatch(
            self: @ComponentState<TContractState>,
            destination_domain: u32,
            message_body: Bytes,
            hook_metadata: Bytes,
            hook: ContractAddress
        ) -> u256 {
            let router = self._must_have_remote_router(destination_domain);

            let mut mailbox_comp = get_dep_component!(self, MailBoxClient);
            mailbox_comp
                .mailbox
                .read()
                .quote_dispatch(
                    destination_domain,
                    router,
                    message_body,
                    Option::Some(hook_metadata),
                    Option::Some(hook)
                )
        }
    }
}
