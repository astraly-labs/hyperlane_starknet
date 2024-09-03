use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypNative<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn receive(ref self: TState, amount: u256);
}

#[starknet::component]
pub mod HypNativeComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::{
        GasRouterComponent,
        GasRouterComponent::{GasRouterInternalImpl, InternalTrait as GasRouterInternalTrait}
    };
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientImpl
    };
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent,
        RouterComponent::{InternalTrait as RouterInternalTrait, RouterComponentInternalImpl}
    };
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl, ITokenRouter
    };
    use hyperlane_starknet::contracts::token::interfaces::imessage_recipient::IMessageRecipient;
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl, OwnableComponent::OwnableImpl
    };
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::ContractAddress;


    #[storage]
    struct Storage {
        eth_token: IERC20Dispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Donation: Donation,
    }

    #[derive(Drop, starknet::Event)]
    struct Donation {
        sender: ContractAddress,
        amount: u256,
    }

    #[embeddable_as(HypNativeImpl)]
    impl HypNative<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of super::IHypNative<ComponentState<TContractState>> {
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.eth_token.read().balance_of(account)
        }

        fn receive(ref self: ComponentState<TContractState>, amount: u256) {
            self.eth_token.read().transfer(starknet::get_contract_address(), amount);

            self.emit(Donation { sender: starknet::get_caller_address(), amount });
        }
    }

    #[embeddable_as(MessageRecipientImpl)]
    impl MessageRecipient<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of IMessageRecipient<ComponentState<TContractState>> {
        fn handle(
            ref self: ComponentState<TContractState>,
            origin: u32,
            sender: Option<ContractAddress>,
            message: Bytes
        ) {
            let amount = message.amount();
            let recipient = message.recipient();

            self._transfer_to(recipient, amount);

            let mut token_router = get_dep_component_mut!(ref self, TokenRouter);
            token_router
                .emit(TokenRouterComponent::ReceivedTransferRemote { origin, recipient, amount, });
        }
    }

    #[embeddable_as(TokenRouterImpl)]
    impl TokenRouter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailboxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouterComp: TokenRouterComponent::HasComponent<TContractState>,
    > of ITokenRouter<ComponentState<TContractState>> {
        // msg_Value use
        fn transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            assert!(msg_value >= amount, "Native: amount exceeds msg.value");
            let hook_payment = msg_value - amount;

            self
                ._transfer_remote(
                    destination, recipient, amount, hook_payment, Option::None, Option::None
                )
        }
    }

    #[generate_trait]
    pub impl HypNativeInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailboxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouterComp: TokenRouterComponent::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) -> Bytes {
            BytesTrait::new_empty() // this can be implemented
        }

        fn _transfer_to(
            ref self: ComponentState<TContractState>, recepient: ContractAddress, amount: u256
        ) {
            self.eth_token.read().transfer(recepient, amount);
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

            let mut message_id = 0;
            let mut router = get_dep_component_mut!(ref self, Router);
            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }
                    message_id = router
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let mut gas_router = get_dep_component_mut!(ref self, GasRouter);
                    let hook_metadata = gas_router._Gas_router_hook_metadata(destination);
                    let mailboxclient = get_dep_component_mut!(ref self, MailboxClient);
                    let hook = mailboxclient.get_hook();
                    message_id = router
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            let mut token_router = get_dep_component_mut!(ref self, TokenRouterComp);
            token_router
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }
}

