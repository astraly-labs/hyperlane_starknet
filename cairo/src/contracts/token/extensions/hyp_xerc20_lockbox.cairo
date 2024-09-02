#[starknet::interface]
pub trait IHypXERC20Lockbox<TState> {
    fn approve_lockbox(ref self: TState);
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
        token_message::TokenMessageTrait, token_router::TokenRouterComponent,
    };
    use hyperlane_starknet::contracts::token::interfaces::ixerc20::{
        IXERC20Dispatcher, IXERC20DispatcherTrait
    };
    use hyperlane_starknet::contracts::token::interfaces::ixerc20_lockbox::{
        IXERC20LockboxDispatcher, IXERC20LockboxDispatcherTrait
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
        path: HypErc20CollateralComponent, storage: collateral, event: HypErc20CollateralEvent
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
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    // HypERC20Collateral
    #[abi(embed_v0)]
    impl HypErc20CollateralImpl =
        HypErc20CollateralComponent::HypErc20CollateralImpl<ContractState>;
    impl HypErc20CollateralInternalImpl = HypErc20CollateralComponent::InternalImpl<ContractState>;
    // TokenRouter
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    impl TokenRouterInternalImpl = TokenRouterComponent::TokenRouterInternalImpl<ContractState>;

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
                IERC20Dispatcher { contract_address: self.xerc20.read().contract_address }
                    .approve(lockbox_address, BoundedInt::max()),
                "xerc20 lockbox approve failed"
            );
        }
    }
    // Overridesss
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, amount: u256) -> Bytes {
            self.collateral.transfer_from_sender(amount);

            self.lockbox.read().deposit(amount);

            self.xerc20.read().burn(starknet::get_contract_address(), amount);
            BytesTrait::new_empty()
        }

        fn transfer_to(ref self: ContractState, recipient: u256, amount: u256, metadata: u256) {
            self.xerc20.read().mint(starknet::get_contract_address(), amount);
            self.lockbox.read().withdraw_to(recipient, amount);
        }
    }
}
