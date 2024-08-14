use alexandria_bytes::Bytes;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ITokenRouter<TState> {
    fn transfer_remote(
        ref self: TState,
        destination: u32,
        recipient: u256,
        amount_or_id: u256,
        value: u256,
        hook_metadata: Option<Bytes>,
        hook: Option<ContractAddress>
    ) -> u256;
}

#[starknet::component]
pub mod TokenRouterComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::{
        GasRouterComponent, GasRouterComponent::GasRouterInternalImpl
    };
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
        MailboxclientComponent::MailboxClient
    };
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent, RouterComponent::RouterComponentInternalImpl, IRouter,
    };
    use hyperlane_starknet::contracts::token::libs::token_message::TokenMessageTrait;
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as OwnableInternalImpl
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SentTransferRemote: SentTransferRemote,
        ReceivedTransferRemote: ReceivedTransferRemote,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SentTransferRemote {
        pub destination: u32,
        pub recipient: u256,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ReceivedTransferRemote {
        pub origin: u32,
        pub recipient: u256,
        pub amount: u256,
    }

    #[embeddable_as(TokenRouterImpl)]
    impl TokenRouter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
    > of super::ITokenRouter<ComponentState<TContractState>> {
        fn transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            match hook_metadata {
                Option::Some(hook_metadata) => {
                    self
                        ._transfer_remote(
                            destination,
                            recipient,
                            amount_or_id,
                            value,
                            Option::Some(hook_metadata),
                            hook
                        )
                },
                Option::None => {
                    self
                        ._transfer_remote(
                            destination, recipient, amount_or_id, value, Option::None, Option::None
                        )
                }
            }
        }
    }

    #[generate_trait]
    pub impl TokenRouterInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, mailbox: ContractAddress) {
            let mut gas_router_comp = get_dep_component_mut!(ref self, GasRouter);
            gas_router_comp.initialize(mailbox);
        }

        fn _transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let token_metadata = self._transfer_from_sender(amount_or_id);
            let token_message = TokenMessageTrait::format(recipient, amount_or_id, token_metadata);

            let mut router_comp = get_dep_component!(@self, Router);
            let mailbox_comp = get_dep_component!(@self, MailBoxClient);
            let gas_router_comp = get_dep_component!(@self, GasRouter);

            let mut message_id = 0;

            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }

                    message_id = router_comp
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let hook_metadata = gas_router_comp._Gas_router_hook_metadata(destination);
                    let hook = mailbox_comp.get_hook();
                    message_id = router_comp
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            self.emit(SentTransferRemote { destination, recipient, amount: amount_or_id, });

            message_id
        }

        fn _transfer_from_sender(
            ref self: ComponentState<TContractState>, amount_or_id: u256
        ) -> Bytes {
            BytesTrait::new_empty()
        }

        fn _handle(ref self: ComponentState<TContractState>, origin: u32, message: Bytes) {
            let recipient = message.recipient();
            let amount = message.amount();
            let metadata = message.metadata();

            self._transfer_to(recipient, amount, metadata);

            self.emit(ReceivedTransferRemote { origin, recipient, amount, });
        }

        fn _transfer_to(
            ref self: ComponentState<TContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {}
    }
}

