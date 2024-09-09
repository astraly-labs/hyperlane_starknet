#[starknet::interface]
trait IHypErc20Vault<TContractState> {
    fn assets_to_shares(self: @TContractState, amount: u256) -> u256;
    fn shares_to_assets(self: @TContractState, shares: u256) -> u256;
    fn share_balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;
    // getters
    fn get_precision(self: @TContractState) -> u256;
    fn get_collateral_domain(self: @TContractState) -> u32;
    fn get_exchange_rate(self: @TContractState) -> u256;
}

#[starknet::contract]
mod HypErc20Vault {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::zeroable::NonZero;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent, RouterComponent::IMessageRecipientInternalHookTrait
    };
    use hyperlane_starknet::contracts::libs::math;
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_component::{HypErc20Component, HypErc20Component::TokenRouterHooksImpl,},
        token_router::{
            TokenRouterComponent,
            TokenRouterComponent::{TokenRouterHooksTrait, TokenRouterTransferRemoteHookTrait}
        }
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{
        ERC20Component, ERC20HooksEmptyImpl, interface::{IERC20Metadata, ERC20ABI}
    };
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(path: HypErc20Component, storage: hyp_erc20, event: HypErc20Event);
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
    // ERC20
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    // HypERC20
    impl HypErc20InternalImpl = HypErc20Component::InternalImpl<ContractState>;
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // E10
    const E10: u256 = 10_000_000_000;
    const PRECISION: u256 = E10;

    #[storage]
    struct Storage {
        exchange_rate: u256,
        collateral_domain: u32,
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
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
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
        TokenRouterEvent: TokenRouterComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        decimals: u8,
        mailbox: ContractAddress,
        total_supply: u256,
        name: ByteArray,
        symbol: ByteArray,
        collateral_domain: u32,
        wrapped_token: ContractAddress,
        owner: ContractAddress,
        hook: ContractAddress,
        interchain_security_module: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self
            .mailbox
            .initialize(mailbox, Option::Some(hook), Option::Some(interchain_security_module));
        self.hyp_erc20.initialize(decimals);
        self.erc20.initializer(name, symbol);
        self.erc20.mint(starknet::get_caller_address(), total_supply);
        self.collateral_domain.write(collateral_domain);
        self.exchange_rate.write(E10);
    }

    impl TokenRouterTransferRemoteHookImpl of TokenRouterTransferRemoteHookTrait<ContractState> {
        fn _transfer_remote(
            ref self: TokenRouterComponent::ComponentState<ContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let shares = contract_state.assets_to_shares(amount_or_id);
            TokenRouterHooksImpl::transfer_from_sender_hook(ref self, shares);
            let token_message = TokenMessageTrait::format(
                recipient, shares, BytesTrait::new_empty()
            );
            let mut message_id = 0;

            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }

                    message_id = contract_state
                        .router
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let hook_metadata = contract_state
                        .gas_router
                        ._Gas_router_hook_metadata(destination);
                    let hook = contract_state.mailbox.get_hook();
                    message_id = contract_state
                        .router
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            self
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }


    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the contract to a new implementation.
        /// Callable only by the owner
        /// # Arguments
        ///
        /// * `new_class_hash` - The class hash of the new implementation.
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl HypeErc20Vault of super::IHypErc20Vault<ContractState> {
        fn assets_to_shares(self: @ContractState, amount: u256) -> u256 {
            math::mul_div(amount, PRECISION, self.exchange_rate.read())
        }

        fn shares_to_assets(self: @ContractState, shares: u256) -> u256 {
            math::mul_div(shares, self.exchange_rate.read(), PRECISION)
        }

        fn share_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn get_precision(self: @ContractState) -> u256 {
            PRECISION
        }

        fn get_collateral_domain(self: @ContractState) -> u32 {
            self.collateral_domain.read()
        }

        fn get_exchange_rate(self: @ContractState) -> u256 {
            self.exchange_rate.read()
        }
    }

    impl MessageRecipientInternalHookImpl of IMessageRecipientInternalHookTrait<ContractState> {
        fn _handle(
            ref self: RouterComponent::ComponentState<ContractState>,
            origin: u32,
            sender: u256,
            message: Bytes
        ) {
            let mut contract_state = RouterComponent::HasComponent::get_contract_mut(ref self);
            if origin == contract_state.collateral_domain.read() {
                let (_, exchange_rate) = message.metadata().read_u256(0);
                contract_state.exchange_rate.write(exchange_rate);
            }
            TokenRouterComponent::MessageRecipientInternalHookImpl::_handle(
                ref self, origin, sender, message
            );
        }
    }

    #[abi(embed_v0)]
    impl ERC20ABIImpl of ERC20ABI<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            ERC20MixinImpl::total_supply(self)
        }
        // Overrides ERC20.balance_of()
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let balance = ERC20MixinImpl::balance_of(self, account);
            self.shares_to_assets(balance)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            ERC20MixinImpl::allowance(self, owner, spender)
        }
        // Overrides ERC20.transfer()
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            ERC20MixinImpl::transfer(ref self, recipient, self.assets_to_shares(amount));
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20MixinImpl::transfer_from(ref self, sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            ERC20MixinImpl::approve(ref self, spender, amount)
        }

        // IERC20Metadata
        fn name(self: @ContractState) -> ByteArray {
            ERC20MixinImpl::name(self)
        }

        fn symbol(self: @ContractState) -> ByteArray {
            ERC20MixinImpl::symbol(self)
        }
        // Overrides ERC20.decimals
        fn decimals(self: @ContractState) -> u8 {
            self.hyp_erc20.decimals.read()
        }

        fn totalSupply(self: @ContractState) -> u256 {
            ERC20MixinImpl::totalSupply(self)
        }
        // Overrides ERC20.balanceOf()
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            let balance = ERC20MixinImpl::balance_of(self, account);
            self.shares_to_assets(balance)
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20MixinImpl::transferFrom(ref self, sender, recipient, amount)
        }
    }
}
