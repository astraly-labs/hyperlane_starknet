#[starknet::interface]
pub trait IHypNativeScaled<TState> {
    fn transfer_remote(self: @TState, destination: u32, recipient: u256, amount: u256) -> u256;
}

#[starknet::contract]
pub mod HypNativeScaled {
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_native_component::{
        HypNativeComponent
    };
    use hyperlane_starknet::contracts::token::components::token_router::TokenRouterComponent;
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
    impl MailboxClientInternalImpl = MailboxclientComponent::MailboxClientInternalImpl<ContractState>;

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
    fn constructor(ref self: ContractState, owner: ContractAddress, scale: u256, mailbox: ContractAddress) {
        self.mailboxclient.initialize(mailbox, Option::None, Option::None);
        self.ownable.initializer(owner);
        self.scale.write(scale);
    }
    //override
    impl HypNativeScaledImpl of super::IHypNativeScaled<ContractState> {
        // need a way to derive hook fee. 
        fn transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount: u256,
            mgs_value: u256
        ) -> u256 {
            assert!(mgs_value >= amount, "Native: amount exceeds msg.value");
            let hook_payment = mgs_value - amount;
            let scaled_amount = amount / scale;
            self.token_router._transfer_remote(destination, recipient, scaled_amount, hook_payment, Option::None, Option::None);
        }
    }
    // override
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_to(ref self: ContractState, recipient: ContractAddress, amount: u256, metadata: u256) {
            let scaled_amount = amount * self.scale.read();
            self.hyp_native.transfer_to(recipient, scaled_amount);
        }
    }
}
