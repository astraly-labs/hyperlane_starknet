#[starknet::interface]
pub trait IHypERC721URIStorage<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState, account: u256) -> u256;
    fn token_uri(self: @TState, token_id: u256) -> u256;
    fn supports_interface(self: @TState, interface_id: u256) -> bool;
}

#[starknet::contract]
pub mod HypERC721URIStorage {
    use openzeppelin::access::ownable::OwnableComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::token::components::token_router::TokenRouterComponent;
    use hyperlane_starknet::contracts::token::components::hyp_erc721_component::HypErc721Component;
    use openzeppelin::token::erc721::{ERC721Component. ERC721HooksEmptyImpl};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterComponent);
    component!(path: HypErc721Component, storage: hyp_erc721, event: HypErc721Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Ecent)

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // MailboxClient
    #[abi(embed_v0)]
    impl MailboxClientImpl = MailboxclientComponent::MailboxClientImpl<ContractState>;
    impl MailboxClientInternalImpl = MailboxclientComponent::MailboxClientInternalImpl<ContractState>;

    //Router
    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;

    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;

    // TokenRouter
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;

    //HypERC721

    impl HypErc721Impl = HypErc721Component::HypErc721Impl<ContractState>;
    impl HypErc721InternalImpl = HypErc721Component::HypErc721Impl<ContractState>;

    //ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    //SRC5

    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::SRC5InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        hyp_erc721: HypErc721Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[constructor]
    fn constructor(
        ref self: COntractState,
        owner: COntractAddress
    ) {
        self.ownable._transfer_ownership(owner)
        self.mailboxclient.initialize(maiblox, Option::None, Option::None);
    }

    impl HypERC721URIStorageImpl of super::IHypERC721URIStorage<ContractState> {
        fn initialize(
            ref self: ContractState,
            _mint_amount: u256,
            _name: ByteArray,
            _symbol: ByteArray,
            _hook: ContractAddress,
            _interchainSecurityModule: ContractAddress,
            owner: ContractAddress
        ) {
            self.ownable.initializer(owner);
            let mailbox = self.mailboxclient.mailbox.read();
            self.mailboxclient.initialize(mailbox, Option::<_hook>, Option::<_interchainSecurityModule>);
            self.hyp_erc721.initialize(
                _mint_amount,
                _name,
                _symbol
            );
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc721.balance_of(account)
        }

        fn token_uri(self: @ContractState, token_id: u256) -> u256 {
            self.erc721.token_uri(token_id)
        }

        fn supports_interface(self: @ContractState, interface_id: u256) -> bool {
            self.src5.supports_interface(interface_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, token_id: u256) -> u256 {
            self.hyp_erc721.transfer_from_sender(token_id);
            return token_id
        }

        fn transfer_to(ref self: ContractState, recipient: u256, token_id: u256, token_uri: u256) {
            self.hyp_erc721.transfer_to(recipient, token_id);
        }

        fn before_token_transfer(
            ref self: ContractState, from: u256, to: u256, token_id: u256, batch_size: u256
        ) {
            self.erc721.before_update(to, token_id, "");
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.burn(token_id);
        }
    }
}
