#[starknet::interface]
pub trait IFastHypERC20<TState> {
    fn balance_of(self: @TState, account: starknet::ContractAddress) -> u256;
}

#[starknet::contract]
pub mod FastHypERC20Collateral {
    use alexandria_bytes::Bytes;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_collateral_component::HypErc20CollateralComponent,
        token_message::TokenMessageTrait,
        token_router::{TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait},
        fast_token_router::{
            FastTokenRouterComponent, FastTokenRouterComponent::FastTokenRouterHooksTrait
        }
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(
        path: FastTokenRouterComponent, storage: fast_token_router, event: FastTokenRouterEvent
    );
    component!(
        path: HypErc20CollateralComponent, storage: collateral, event: HypErc20CollateralEvent
    );
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

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
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    // HypERC20Collateral
    #[abi(embed_v0)]
    impl HypErc20CollateralImpl =
        HypErc20CollateralComponent::HypErc20CollateralImpl<ContractState>;
    impl HypErc20CollateralInternalImpl = HypErc20CollateralComponent::InternalImpl<ContractState>;
    // TokenRouter
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;
    // FastTokenRouter
    #[abi(embed_v0)]
    impl FastTokenRouterImpl =
        FastTokenRouterComponent::FastTokenRouterImpl<ContractState>;
    impl FastTokenRouterInternalImpl = FastTokenRouterComponent::InternalImpl<ContractState>;
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        collateral: HypErc20CollateralComponent::Storage,
        #[substorage(v0)]
        mailbox: MailboxclientComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        fast_token_router: FastTokenRouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
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
        #[flat]
        FastTokenRouterEvent: FastTokenRouterComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        mailbox: ContractAddress,
        wrapped_token: ContractAddress,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
        owner: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self
            .mailbox
            .initialize(mailbox, Option::Some(hook), Option::Some(interchain_security_module));
        self.collateral.initialize(wrapped_token);
    }

    impl FastHypERC20Impl of super::IFastHypERC20<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.collateral.balance_of(account)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: core::starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    pub impl TokenRouterHooksImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>, amount_or_id: u256
        ) -> Bytes {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            contract_state.collateral._transfer_from_sender(amount_or_id)
        }

        // should this override this interface or be seperate function. has extra origin parameter
        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes,
            //origin: u32 
        ) {
            let origin = 0; //Dummy origin
            let contract_state = TokenRouterComponent::HasComponent::get_contract(@self);
            let token_recipient = contract_state
                .fast_token_router
                ._get_token_recipient(recipient, amount_or_id, origin, metadata);
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            contract_state.fast_token_router.fast_transfer_to_hook(token_recipient, amount_or_id);
        }
    }

    pub impl FastTokenRouterHooksImpl of FastTokenRouterHooksTrait<ContractState> {
        fn fast_transfer_to_hook(
            ref self: FastTokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount: u256
        ) {
            let mut contract_state = FastTokenRouterComponent::HasComponent::get_contract_mut(
                ref self
            );
            contract_state
                .collateral
                .wrapped_token
                .read()
                .transfer(recipient.try_into().expect('u256 to ContractAddress failed'), amount);
        }
        fn fast_receive_from_hook(
            ref self: FastTokenRouterComponent::ComponentState<ContractState>,
            sender: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = FastTokenRouterComponent::HasComponent::get_contract_mut(
                ref self
            );
            contract_state
                .collateral
                .wrapped_token
                .read()
                .transfer_from(sender, starknet::get_contract_address(), amount);
        }
    }
    // TODO: This should override the _handle at Router
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn handle(ref self: ContractState, origin: u32, message: Bytes) {
            self.fast_token_router._handle(origin, message);
        }
    }
}
