#[starknet::interface]
pub trait IHypNativeScaled<TState> {
    fn transfer_remote(
        ref self: TState, destination: u32, recipient: u256, amount: u256, msg_value: u256
    ) -> u256;
}

#[starknet::contract]
pub mod HypNativeScaled {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_native_component::{
        HypNativeComponent
    };
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, ITokenRouter
    };
    use hyperlane_starknet::contracts::token::interfaces::imessage_recipient::IMessageRecipient;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::interface::IERC721Dispatcher;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: HypNativeComponent, storage: hyp_native, event: HypNativeEvent);

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // HypERC721
    #[abi(embed_v0)]
    impl HypNativeImpl = HypNativeComponent::HypNativeImpl<ContractState>;
    impl HypNativeInternalImpl = HypNativeComponent::HypNativeInternalImpl<ContractState>;
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    impl GasRouterInternalImpl = GasRouterComponent::GasRouterInternalImpl<ContractState>;
    // Router
    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;
    // MailboxClient
    #[abi(embed_v0)]
    impl MailboxClientImpl =
        MailboxclientComponent::MailboxClientImpl<ContractState>;
    impl MailboxClientInternalImpl =
        MailboxclientComponent::MailboxClientInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        scale: u256,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        hyp_native: HypNativeComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        TokenRouterEvent: TokenRouterComponent::Event,
        #[flat]
        MailboxclientEvent: MailboxclientComponent::Event,
        #[flat]
        RouterEvent: RouterComponent::Event,
        #[flat]
        GasRouterEvent: GasRouterComponent::Event,
        #[flat]
        HypNativeEvent: HypNativeComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, scale: u256, mailbox: ContractAddress
    ) {
        self.mailboxclient.initialize(mailbox, Option::None, Option::None);
        self.ownable.initializer(owner);
        self.scale.write(scale);
    }
    //override
    impl HypNativeScaledImpl of super::IHypNativeScaled<ContractState> {
        fn transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount: u256,
            msg_value: u256
        ) -> u256 {
            assert!(msg_value >= amount, "Native: amount exceeds msg.value");
            let hook_payment = msg_value - amount;
            let scaled_amount = amount / self.scale.read();
            self
                ._transfer_remote(
                    destination, recipient, scaled_amount, hook_payment, Option::None, Option::None
                )
        }
    }

    #[abi(embed_v0)]
    impl MessageRecipient of IMessageRecipient<ContractState> {
        fn handle(
            ref self: ContractState, origin: u32, sender: Option<ContractAddress>, message: Bytes
        ) {
            let amount = message.amount();
            let recipient = message.recipient();

            self._transfer_to(recipient, amount);

            self
                .token_router
                .emit(TokenRouterComponent::ReceivedTransferRemote { origin, recipient, amount, });
        }
    }

    #[abi(embed_v0)]
    impl TokenRouter of ITokenRouter<ContractState> {
        fn transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let token_metadata = self.hyp_native._transfer_from_sender(amount_or_id);
            let token_message = TokenMessageTrait::format(recipient, amount_or_id, token_metadata);

            let mut message_id = 0;

            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }

                    message_id = self
                        .router
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let hook_metadata = self.gas_router._Gas_router_hook_metadata(destination);
                    let hook = self.mailboxclient.get_hook();
                    message_id = self
                        .router
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            self
                .token_router
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer_to(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let scaled_amount = amount * self.scale.read();
            self.hyp_native._transfer_to(recipient, scaled_amount);
        }
        fn _transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let token_metadata = self.hyp_native._transfer_from_sender(amount_or_id);
            let token_message = TokenMessageTrait::format(recipient, amount_or_id, token_metadata);

            let mut message_id = 0;

            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }

                    message_id = self
                        .router
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let hook_metadata = self.gas_router._Gas_router_hook_metadata(destination);
                    let hook = self.mailboxclient.get_hook();
                    message_id = self
                        .router
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            self
                .token_router
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }
}
