#[starknet::interface]
trait IHypErc20Vault<TContractState> {
    fn assets_to_shares(self: @TContractState, amount: u256) -> u256;
    fn shares_to_assets(self: @TContractState, shares: u256) -> u256;
    fn share_balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;
}

#[starknet::contract]
mod HypErc20Vault {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::integer::{u256_wide_mul, u512_safe_div_rem_by_u256};
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::zeroable::NonZero;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::{RouterComponent, RouterComponent::IMessageRecipientInternalHookTrait};
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_component::{
            HypErc20Component, 
            HypErc20Component::TokenRouterHooksImpl, },
        token_router::{
            TokenRouterComponent, 
            TokenRouterComponent::TokenRouterHooksTrait
        }
    };
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{
        ERC20Component, ERC20HooksEmptyImpl, 
        interface::{IERC20Metadata, ERC20ABI} 
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
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    // ERC20
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    // HypERC20
    impl HypErc20InternalImpl = HypErc20Component::InternalImpl<ContractState>;
    // TokenRouter
    #[abi(embed_v0)]
    impl TokenRouterImpl = TokenRouterComponent::TokenRouterImpl<ContractState>;
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

    // _transfer_remote override

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl HypeErc20Vault of super::IHypErc20Vault<ContractState> {
        fn assets_to_shares(self: @ContractState, amount: u256) -> u256 {
            mul_div(amount, PRECISION, self.exchange_rate.read())
        }

        fn shares_to_assets(self: @ContractState, shares: u256) -> u256 {
            mul_div(shares, self.exchange_rate.read(), PRECISION)
        }

        fn share_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }
    }

    impl MessageRecipientInternalHookImpl of IMessageRecipientInternalHookTrait<ContractState> {
        fn _handle(ref self: RouterComponent::ComponentState<ContractState>, origin: u32, sender: u256, message: Bytes) {
            let mut contract_state = RouterComponent::HasComponent::get_contract_mut(ref self);
            if origin == contract_state.collateral_domain.read() {
                let (_, exchange_rate) = message.metadata().read_u256(0);
                contract_state.exchange_rate.write(exchange_rate);
            }   
            TokenRouterComponent::MessageRecipientInternalHookImpl::_handle(ref self, origin, sender, message);
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
        fn transfer(
            ref self: ContractState, recipient: ContractAddress, amount: u256
        ) -> bool {
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

        fn approve(
            ref self: ContractState, spender: ContractAddress, amount: u256
        ) -> bool {
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

    /// Multiplies two `u256` values and then divides by a third `u256` value.
    ///
    /// # Parameters
    ///
    /// - `a`: The first multiplicand, a `u256` value.
    /// - `b`: The second multiplicand, a `u256` value.
    /// - `c`: The divisor, a `u256` value. Must not be zero.
    ///
    /// # Returns
    ///
    /// - The result of the operation `(a * b) / c`, as a `u256` value.
    ///
    /// # Panics
    ///
    /// - Panics if `c` is zero, as division by zero is undefined.
    pub fn mul_div(a: u256, b: u256, c: u256) -> u256 {
        if c == 0 {
            panic!("mul_div division by zero");
        }
        let (q, _) = u512_safe_div_rem_by_u256(u256_wide_mul(a, b), c.try_into().unwrap());
        q.try_into().expect('mul_div result gt u256')
    }
}
