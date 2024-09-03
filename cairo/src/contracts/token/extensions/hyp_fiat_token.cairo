#[starknet::interface]
pub trait IHypFiatToken<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypFiatToken {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_erc721_collateral_component::{
        HypErc721CollateralComponent, IHypErc721Collateral
    };
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait
    };
    use hyperlane_starknet::contracts::token::interfaces::ifiat_token::{
        IFiatTokenDispatcher, IFiatTokenDispatcherTrait
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait,};
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(
        path: HypErc721CollateralComponent,
        storage: hyp_erc721_collateral,
        event: HypErc721CollateralEvent
    );

    // HypERC721
    #[abi(embed_v0)]
    impl HypErc721CollateralImpl =
        HypErc721CollateralComponent::HypErc721CollateralImpl<ContractState>;

    // TokenRouter
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;

    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;

    // Router
    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;

    // MailboxClient
    #[abi(embed_v0)]
    impl MailboxClientImpl =
        MailboxclientComponent::MailboxClientImpl<ContractState>;

    #[storage]
    struct Storage {
        wrapped_token: ERC721ABIDispatcher,
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
        hyp_erc721_collateral: HypErc721CollateralComponent::Storage
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
        HypErc721CollateralEvent: HypErc721CollateralComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, erc721: ContractAddress, mailbox: ContractAddress) {
        self.token_router.initialize(mailbox);

        self.wrapped_token.write(ERC721ABIDispatcher { contract_address: erc721 });
    }

    impl TokenRouterHooksImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>, amount_or_id: u256
        ) -> Bytes {
            let contract_state = TokenRouterComponent::HasComponent::get_contract(@self);
            let wrapped_token_dispatcher = contract_state.wrapped_token.read();

            wrapped_token_dispatcher
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount_or_id
                );

            let wrapped_token = IFiatTokenDispatcher {
                contract_address: wrapped_token_dispatcher.contract_address
            };
            wrapped_token.burn(amount_or_id);

            BytesTrait::new_empty()
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let contract_state = TokenRouterComponent::HasComponent::get_contract(@self);
            let wrapped_token = IFiatTokenDispatcher {
                contract_address: contract_state.wrapped_token.read().contract_address
            };

            wrapped_token.mint(amount_or_id);
        }
    }
}
