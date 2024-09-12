#[starknet::interface]
trait IERC4626YieldSharing<TContractState> {
    fn set_fee(ref self: TContractState, new_fee: u256);
    fn get_claimable_fees(self: @TContractState) -> u256;
}

#[starknet::contract]
mod ERC4626YieldSharingMock {
    use core::integer::BoundedInt;
    use hyperlane_starknet::contracts::libs::math;
    use hyperlane_starknet::contracts::mocks::erc4626_component::{
        ERC4626Component, ERC4626HooksEmptyImpl
    };
    use hyperlane_starknet::contracts::token::interfaces::ierc4626::IERC4626;
    use openzeppelin::access::ownable::{OwnableComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{get_contract_address, get_caller_address, ContractAddress};

    component!(path: ERC4626Component, storage: erc4626, event: ERC4626Event);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    impl ERC4626Impl = ERC4626Component::ERC4626Impl<ContractState>;
    impl ERC4626InternalImpl = ERC4626Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // E18
    const SCALE: u256 = 1_000_000_000_000_000_000;

    #[storage]
    struct Storage {
        fee: u256,
        accumulated_fees: u256,
        last_vault_balance: u256,
        #[substorage(v0)]
        erc4626: ERC4626Component::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC4626Event: ERC4626Component::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        asset: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_fee: u256
    ) {
        self.erc4626.initializer(asset, name, symbol, 0);
        self.fee.write(initial_fee);
        self.ownable.initializer(get_caller_address());
    }

    pub impl ERC4626YieldSharingImpl of super::IERC4626YieldSharing<ContractState> {
        fn set_fee(ref self: ContractState, new_fee: u256) {
            self.ownable.assert_only_owner();
            self.fee.write(new_fee);
        }

        fn get_claimable_fees(self: @ContractState) -> u256 {
            let new_vault_balance = IERC20Dispatcher { contract_address: self.erc4626.asset() }
                .balance_of(get_contract_address());
            let last_vault_balance = self.last_vault_balance.read();
            if new_vault_balance <= last_vault_balance {
                return self.accumulated_fees.read();
            }

            let new_yield = new_vault_balance - last_vault_balance;
            let new_fees = math::mul_div(new_yield, self.fee.read(), SCALE);

            self.accumulated_fees.read() + new_fees
        }
    }

    pub impl ERC4626 of IERC4626<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc4626.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc4626.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc4626.decimals()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc4626.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc4626.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.erc4626.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.erc4626.transfer(recipient, amount)
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.erc4626.transfer_from(sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc4626.approve(spender, amount)
        }

        fn asset(self: @ContractState) -> ContractAddress {
            self.erc4626.asset()
        }

        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            self.erc4626.convert_to_assets(shares)
        }

        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            self.erc4626.convert_to_shares(assets)
        }
        // Overriden
        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            let last_vault_balance = self.last_vault_balance.read();
            self.last_vault_balance.write(last_vault_balance + assets);
            self.erc4626.deposit(assets, receiver)
        }

        fn mint(ref self: ContractState, shares: u256, receiver: ContractAddress) -> u256 {
            self.erc4626.mint(shares, receiver)
        }

        fn preview_deposit(self: @ContractState, assets: u256) -> u256 {
            self.erc4626.preview_deposit(assets)
        }

        fn preview_mint(self: @ContractState, shares: u256) -> u256 {
            self.erc4626.preview_mint(shares)
        }

        fn preview_redeem(self: @ContractState, shares: u256) -> u256 {
            self.erc4626.preview_redeem(shares)
        }

        fn preview_withdraw(self: @ContractState, assets: u256) -> u256 {
            self.erc4626.preview_withdraw(assets)
        }

        fn max_deposit(self: @ContractState, receiver: ContractAddress) -> u256 {
            BoundedInt::max()
        }

        fn max_mint(self: @ContractState, receiver: ContractAddress) -> u256 {
            BoundedInt::max()
        }

        fn max_redeem(self: @ContractState, owner: ContractAddress) -> u256 {
            self.erc4626.max_redeem(owner)
        }

        fn max_withdraw(self: @ContractState, owner: ContractAddress) -> u256 {
            self.erc4626.max_withdraw(owner)
        }
        // Overriden
        fn redeem(
            ref self: ContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            self._accrue_yield();
            self.erc4626.redeem(shares, receiver, owner)
        }
        // Overriden
        fn total_assets(self: @ContractState) -> u256 {
            self.erc4626.total_assets() - self.get_claimable_fees()
        }

        fn withdraw(
            ref self: ContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            self.erc4626.withdraw(assets, receiver, owner)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _accrue_yield(ref self: ContractState) {
            let new_vault_balance = IERC20Dispatcher { contract_address: self.erc4626.asset() }
                .balance_of(get_contract_address());
            let last_vault_balance = self.last_vault_balance.read();
            if new_vault_balance > last_vault_balance {
                let new_yield = new_vault_balance - last_vault_balance;
                let new_fees = math::mul_div(new_yield, self.fee.read(), SCALE);
                let accumulated_fees = self.accumulated_fees.read();
                self.accumulated_fees.write(accumulated_fees + new_fees);
                self.last_vault_balance.write(new_vault_balance);
            }
        }
    }
}
