#[starknet::interface]
trait IHypErc20VaultCollateral<TContractState> {
    fn rebase(ref self: TContractState, destination_domain: u32, value: u256);
    // getters 
    fn get_vault(self: @TContractState) -> starknet::ContractAddress;
    fn get_precision(self: @TContractState) -> u256;
    fn get_null_recipient(self: @TContractState) -> u256;
}

#[starknet::contract]
mod HypErc20VaultCollateral {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::libs::math;
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::{
        token_router::{
            TokenRouterComponent, TokenRouterComponent::MessageRecipientInternalHookImpl,
            TokenRouterComponent::{TokenRouterHooksTrait, TokenRouterTransferRemoteHookTrait}
        },
        hyp_erc20_collateral_component::HypErc20CollateralComponent,
    };
    use hyperlane_starknet::contracts::token::interfaces::ierc4626::{
        ERC4626ABIDispatcher, ERC4626ABIDispatcherTrait
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20ABIDispatcherTrait};
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
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    impl GasRouterInternalImpl = GasRouterComponent::GasRouterInternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
    // HypERC20Collateral
    #[abi(embed_v0)]
    impl HypErc20CollateralImpl =
        HypErc20CollateralComponent::HypErc20CollateralImpl<ContractState>;
    impl HypErc20CollateralInternalImpl = HypErc20CollateralComponent::InternalImpl<ContractState>;
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    // E10
    const PRECISION: u256 = 10_000_000_000;
    const NULL_RECIPIENT: u256 = 1;

    #[storage]
    struct Storage {
        vault: ERC4626ABIDispatcher,
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
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        mailbox: ContractAddress,
        vault: ContractAddress,
        owner: ContractAddress,
        hook: Option<ContractAddress>,
        interchain_security_module: Option<ContractAddress>
    ) {
        self.ownable.initializer(owner);
        self.mailbox.initialize(mailbox, hook, interchain_security_module);
        let vault_dispatcher = ERC4626ABIDispatcher { contract_address: vault };
        let erc20 = vault_dispatcher.asset();
        self.collateral.initialize(erc20);
        self.vault.write(vault_dispatcher);
    }

    impl TokenRouterTransferRemoteHookImpl of TokenRouterTransferRemoteHookTrait<ContractState> {
        fn _transfer_remote( // this overrides specific internal _transfer_remote check parameters ensure any additional thing is needed
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            TokenRouterHooksTraitImpl::transfer_from_sender_hook(ref self, amount_or_id);
            let shares = contract_state._deposit_into_vault(amount_or_id);
            let vault = contract_state.vault.read();
            let exchange_rate = math::mul_div( /// need roundup round down
                PRECISION, vault.total_assets(), vault.total_supply(),
            );
            let token_metadata: Bytes = BytesTrait::new_empty(); //exchange_rate // abi.encode ? 
            let token_message = TokenMessageTrait::format(recipient, shares, token_metadata);
            let message_id = contract_state
                .router
                ._Router_dispatch(
                    destination, value, token_message, hook_metadata.unwrap(), hook.unwrap()
                );
            self
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );
            message_id
        }
    }

    impl TokenRouterHooksTraitImpl of TokenRouterHooksTrait<ContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>, amount_or_id: u256
        ) -> Bytes {
            HypErc20CollateralComponent::TokenRouterHooksImpl::transfer_from_sender_hook(
                ref self, amount_or_id
            )
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let recipient: ContractAddress = recipient.try_into().unwrap();
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            // withdraw with the specified amount of shares
            contract_state
                .vault
                .read()
                .redeem(
                    amount_or_id,
                    recipient.try_into().expect('u256 to ContractAddress failed'),
                    starknet::get_contract_address()
                );
        }
    }

    impl HypeErc20VaultCollateral of super::IHypErc20VaultCollateral<ContractState> {
        fn rebase(ref self: ContractState, destination_domain: u32, value: u256) {
            self
                ._transfer_remote(
                    destination_domain,
                    NULL_RECIPIENT,
                    0,
                    value,
                    BytesTrait::new_empty(),
                    starknet::contract_address_const::<0>()
                );
        }

        fn get_vault(self: @ContractState) -> ContractAddress {
            self.vault.read().contract_address
        }

        fn get_precision(self: @ContractState) -> u256 {
            PRECISION
        }

        fn get_null_recipient(self: @ContractState) -> u256 {
            NULL_RECIPIENT
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _deposit_into_vault(ref self: ContractState, amount: u256) -> u256 {
            let vault = self.vault.read();
            self.collateral.wrapped_token.read().approve(vault.contract_address, amount);
            vault.deposit(amount, starknet::get_contract_address())
        }
    }
}
