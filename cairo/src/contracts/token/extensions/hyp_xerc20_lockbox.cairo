#[starknet::interface]
pub trait IHypXERC20Lockbox<TState> {
    fn approve_lockbox(ref self: TState);
    // getters
    fn get_lockbox(self: @TState) -> starknet::ContractAddress;
    fn get_xerc20(self: @TState) -> starknet::ContractAddress;
}

#[starknet::contract]
pub mod HypXERC20Lockbox {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::integer::BoundedInt;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_collateral_component::HypErc20CollateralComponent,
        token_router::{
            TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait,
            TokenRouterComponent::MessageRecipientInternalHookImpl, TokenRouterTransferRemoteHookDefaultImpl
        },
    };
    use hyperlane_starknet::contracts::token::interfaces::ixerc20::{
        IXERC20Dispatcher, IXERC20DispatcherTrait
    };
    use hyperlane_starknet::contracts::token::interfaces::ixerc20_lockbox::{
        IXERC20LockboxDispatcher, IXERC20LockboxDispatcherTrait
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
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
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    // Token Router
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        collateral: HypErc20CollateralComponent::Storage,
        #[substorage(v0)]
        mailbox: MailboxclientComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        lockbox: IXERC20LockboxDispatcher,
        xerc20: IXERC20Dispatcher,
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
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        mailbox: ContractAddress,
        lockbox: ContractAddress,
        owner: ContractAddress,
        hook: ContractAddress,
        interchain_security_module: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self
            .mailbox
            .initialize(mailbox, Option::Some(hook), Option::Some(interchain_security_module));
        let lockbox_dispatcher = IXERC20LockboxDispatcher { contract_address: lockbox };
        self.collateral.initialize(lockbox_dispatcher.erc20());
        let xerc20 = lockbox_dispatcher.xerc20();
        self.xerc20.write(IXERC20Dispatcher { contract_address: xerc20 });
        self.approve_lockbox();
    }

    impl HypXERC20LockboxImpl of super::IHypXERC20Lockbox<ContractState> {
        fn approve_lockbox(ref self: ContractState) {
            let lockbox_address = self.lockbox.read().contract_address;
            assert!(
                self.collateral.wrapped_token.read().approve(lockbox_address, BoundedInt::max()),
                "erc20 lockbox approve failed"
            );
            assert!(
                ERC20ABIDispatcher { contract_address: self.xerc20.read().contract_address }
                    .approve(lockbox_address, BoundedInt::max()),
                "xerc20 lockbox approve failed"
            );
        }

        fn get_lockbox(self: @ContractState) -> ContractAddress {
            self.lockbox.read().contract_address
        }

        fn get_xerc20(self: @ContractState) -> ContractAddress {
            self.xerc20.read().contract_address
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    impl TokenRouterHooksImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>, amount_or_id: u256
        ) -> Bytes {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            contract_state.collateral._transfer_from_sender(amount_or_id);

            contract_state.lockbox.read().deposit(amount_or_id);

            contract_state.xerc20.read().burn(starknet::get_contract_address(), amount_or_id);
            BytesTrait::new_empty()
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);

            contract_state.xerc20.read().mint(starknet::get_contract_address(), amount_or_id);
            contract_state.lockbox.read().withdraw_to(recipient, amount_or_id);
        }
    }
}

