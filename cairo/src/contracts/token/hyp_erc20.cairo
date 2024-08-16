use starknet::ContractAddress;

#[starknet::contract]
pub mod HypErc20 {
    use hyperlane_starknet::contracts::client::gas_router_component::{GasRouterComponent};

    use hyperlane_starknet::contracts::client::mailboxclient_component::{MailboxclientComponent};
    use hyperlane_starknet::contracts::client::router_component::{RouterComponent};
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_component::HypErc20Component, token_message::TokenMessageTrait,
        token_router::TokenRouterComponent
    };
    use openzeppelin::access::ownable::{OwnableComponent};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;


    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: HypErc20Component, storage: hyp_erc20, event: HypErc20Event);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MailboxClientImpl =
        MailboxclientComponent::MailboxClientImpl<ContractState>;
    impl MailboxClientInternalImpl =
        MailboxclientComponent::MailboxClientInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    impl GasRouterInternalImpl = GasRouterComponent::GasRouterInternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl HypErc20Impl = HypErc20Component::HypeErc20Impl<ContractState>;
    impl HypErc20InternalImpl = HypErc20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        decimals: u8,
        #[substorage(v0)]
        hyp_erc20: HypErc20Component::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
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
        HypErc20Event: HypErc20Component::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        MailBoxClientEvent: MailboxclientComponent::Event,
        #[flat]
        GasRouterEvent: GasRouterComponent::Event,
        #[flat]
        RouterEvent: RouterComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        TokenRouterEvent: TokenRouterComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        decimals: u8,
        mailbox: ContractAddress,
        total_supply: u256,
        name: ByteArray,
        symbol: ByteArray,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
        owner: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.hyp_erc20.initialize(decimals, mailbox);
        self.erc20.initializer(name, symbol);
        self.erc20._mint(starknet::get_caller_address(), total_supply);
        self.mailbox._MailboxClient_initialize(hook, interchain_security_module);
    }
}
