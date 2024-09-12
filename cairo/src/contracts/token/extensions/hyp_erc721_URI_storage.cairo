use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypERC721URIStorage<TState> {
    fn initialize(
        ref self: TState,
        _mint_amount: u256,
        _name: ByteArray,
        _symbol: ByteArray,
        _hook: ContractAddress,
        _interchainSecurityModule: ContractAddress,
        owner: ContractAddress
    );
}

#[starknet::interface]


#[starknet::contract]
pub mod HypERC721URIStorage {
    use openzeppelin::access::ownable::OwnableComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait,
        TokenRouterComponent::MessageRecipientInternalHookImpl,
        TokenRouterTransferRemoteHookDefaultImpl
    };
    use hyperlane_starknet::contracts::token::components::hyp_erc721_component::HypErc721Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721Component::ERC721HooksTrait};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ ContractAddress, get_caller_address };
    use core::num::traits::Zero;
    use alexandria_bytes::{ Bytes, BytesTrait };
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: HypErc721Component, storage: hyp_erc721, event: HypErc721Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

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
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;

    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;

    // TokenRouter
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;

    //HypERC721

    impl HypErc721Impl = HypErc721Component::HypErc721Impl<ContractState>;
    impl HypErc721InternalImpl = HypErc721Component::HypErc721InternalImpl<ContractState>;

    //ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

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
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        MailboxclientEvent: MailboxclientComponent::Event,
        #[flat]
        RouterEvent: RouterComponent::Event,
        #[flat]
        GasRouterEvent: GasRouterComponent::Event,
        #[flat]
        TokenRouterEvent: TokenRouterComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        HypErc721Event: HypErc721Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        mailbox: ContractAddress,
        _mint_amount: u256,
        _name: ByteArray,
        _symbol: ByteArray,
        _base_uri: ByteArray,
        _hook: ContractAddress,
        _interchainSecurityModule: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.mailboxclient.initialize(mailbox, Option::Some(_hook), Option::Some(_interchainSecurityModule));
        self.hyp_erc721.initialize(
            _mint_amount,
            _name,
            _symbol,
            _base_uri
        )
    }

    #[abi(embed_v0)]
    impl HypErc721Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // #[generate_trait]
    // impl InternalImpl of InternalTrait {
    //     fn transfer_from_sender(ref self: ContractState, token_id: u256) -> u256 {
    //         self.hyp_erc721.transfer_from_sender(token_id);
    //         token_id
    //     }

    //     fn transfer_to(ref self: ContractState, recipient: ContractAddress, token_id: u256, token_uri: u256) {
    //         self.hyp_erc721.transfer_to(recipient, token_id);
    //     }

    //     fn before_token_transfer(
    //         ref self: ContractState, from: u256, to: ContractAddress, token_id: u256, batch_size: u256
    //     ) {
    //         self.erc721.before_update(to, token_id, Zero::zero());
    //     }
    // }

    // would be extended when erc721_enumerable is imported
    impl ERC721HooksImpl of ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }


    impl TokenRouterHooksImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            amount_or_id: u256
        ) -> Bytes {
            let contract_state = TokenRouterComponent::HasComponent::get_contract(@self);
            let token_owner = contract_state.erc721.owner_of(amount_or_id);
            assert!(
                token_owner == get_caller_address(),
                "Caller is not owner of token"
            );

            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            contract_state.erc721.burn(amount_or_id);

            BytesTrait::new_empty()
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let recipient_felt: felt252 = recipient.try_into().expect('u256 to felt failed');
            let recipient: ContractAddress = recipient_felt.try_into().unwrap();

            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            contract_state.erc721.mint(recipient, amount_or_id);
        }
    }
}
