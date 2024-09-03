// #[starknet::interface]
// pub trait IHypNativeScaled<TState> {
//     fn initialize(ref self: TState);
//     fn transfer_remote(self: @TState, destination: u32, recipient: u256, amount: u256) -> u256;
//     fn balance_of(self: @TState, account: u256) -> u256;
// }

#[starknet::contract]
pub mod HypNativeScaled {
    use alexandria_bytes::bytes::{BytesTrait, Bytes};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_native_component::{
        HypNativeComponent, IHypNative
    };
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{
        interface::{IERC20Dispatcher, IERC20DispatcherTrait}, ERC20Component, ERC20HooksEmptyImpl
    };
    use openzeppelin::token::erc721::{interface::IERC721Dispatcher, ERC721Component};
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: HypNativeComponent, storage: hyp_native, event: HypNativeEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // HypERC721
    impl HypNativeImpl = HypNativeComponent::HypNativeImpl<ContractState>;

    // TokenRouter
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

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;


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
        hyp_native: HypNativeComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage
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
        HypNativeEvent: HypNativeComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, scale: u256, mailbox: ContractAddress) {
        self.scale.write(scale);
        self.token_router.initialize(mailbox);
    }

    #[abi(embed_v0)]
    impl HypNativeScaledImpl of IHypNative<ContractState> {
        fn initialize(
            ref self: ContractState,
            hook: ContractAddress,
            interchain_security_module: ContractAddress,
            owner: ContractAddress
        ) {
            self.hyp_native.initialize(hook, interchain_security_module, owner);
        }

        fn transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount: u256,
            mgs_value: u256
        ) -> u256 {
            let hook_payment = mgs_value - amount;
            let scaled_amount = amount / self.scale.read();
            self
                .token_router
                ._transfer_remote(
                    destination, recipient, scaled_amount, hook_payment, Option::None, Option::None
                )
        }

        fn receive(ref self: ContractState, amount: u256) {
            self.hyp_native.receive(amount);
        }
    }

    impl TokenRouterHooksImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>, amount_or_id: u256
        ) -> Bytes {
            BytesTrait::new_empty()
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let contract_address = starknet::get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address };
            let recipient_felt: felt252 = recipient.try_into().expect('u256 to felt failed');
            let recipient: ContractAddress = recipient_felt.try_into().unwrap();
            erc20_dispatcher.transfer(recipient, amount_or_id);
        }
    }
}
