#[starknet::contract]
pub mod HypXERC20 {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_erc20_collateral_component::HypErc20CollateralComponent;

    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, ITokenRouter
    };
    use hyperlane_starknet::contracts::token::interfaces::imessage_recipient::IMessageRecipient;

    use hyperlane_starknet::contracts::token::interfaces::ixerc20::{
        IXERC20Dispatcher, IXERC20DispatcherTrait
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(
        path: HypErc20CollateralComponent,
        storage: hyp_erc20_collateral,
        event: HypErc20CollateralEvent
    );

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // MailboxClient
    #[abi(embed_v0)]
    impl MailboxClientImpl =
        MailboxclientComponent::MailboxClientImpl<ContractState>;
    impl MailboxClientInternalImpl =
        MailboxclientComponent::MailboxClientInternalImpl<ContractState>;
    // Router
    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    impl GasRouterInternalImpl = GasRouterComponent::GasRouterInternalImpl<ContractState>;
    // HypERC20Collateral
    #[abi(embed_v0)]
    impl HypErc20CollateralImpl =
        HypErc20CollateralComponent::HypErc20CollateralImpl<ContractState>;
    impl HypErc20CollateralInternalImpl = HypErc20CollateralComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        hyp_erc20_collateral: HypErc20CollateralComponent::Storage,
        #[substorage(v0)]
        mailbox: MailboxclientComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        HypErc20CollateralEvent: HypErc20CollateralComponent::Event,
        #[flat]
        MailBoxClientEvent: MailboxclientComponent::Event,
        #[flat]
        GasRouterEvent: GasRouterComponent::Event,
        #[flat]
        RouterEvent: RouterComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        TokenRouterEvent: TokenRouterComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        mailbox: ContractAddress,
        wrapped_token: ContractAddress,
        owner: ContractAddress,
        hook: ContractAddress,
        interchain_security_module: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self
            .mailbox
            .initialize(mailbox, Option::Some(hook), Option::Some(interchain_security_module));
        self.hyp_erc20_collateral.initialize(wrapped_token);
    }

    #[abi(embed_v0)]
    impl MessageRecipient of IMessageRecipient<ContractState> {
        fn handle(
            ref self: ContractState, origin: u32, sender: Option<ContractAddress>, message: Bytes
        ) {
            let amount = message.amount();
            let metadata = message.metadata();
            let recipient = message.recipient();

            self._transfer_to(recipient, amount, metadata);

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
            let token_metadata = self._transfer_from_sender(amount_or_id);
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
                    let hook = self.mailbox.get_hook();
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
        fn _transfer_from_sender(ref self: ContractState, amount_or_id: u256) -> Bytes {
            let token: IERC20Dispatcher = self.hyp_erc20_collateral.wrapped_token.read();
            IXERC20Dispatcher { contract_address: token.contract_address }
                .burn(starknet::get_caller_address(), amount_or_id);
            BytesTrait::new_empty()
        }

        fn _transfer_to(
            ref self: ContractState, recipient: u256, amount_or_id: u256, metadata: Bytes
        ) {
            let token: IERC20Dispatcher = self.hyp_erc20_collateral.wrapped_token.read();
            IXERC20Dispatcher { contract_address: token.contract_address }
                .mint(recipient.try_into().unwrap(), amount_or_id);
        }
    }
}
