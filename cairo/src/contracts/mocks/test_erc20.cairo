#[starknet::interface]
pub trait ITestERC20<TContractState> {
    fn decimals(self: @TContractState) -> u8;
    fn mint(ref self: TContractState, to: starknet::ContractAddress, amount: u256) -> bool;
    fn mint_to(ref self: TContractState, to: starknet::ContractAddress, amount: u256);
    fn burn_from(ref self: TContractState, from: starknet::ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: starknet::ContractAddress, amount: u256);
    fn burn(ref self: TContractState, amount: u256);
    fn transfer(ref self: TContractState, to: starknet::ContractAddress, amount: u256);
    fn balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;
    fn transfer_from(
        ref self: TContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        amount: u256
    ) -> bool;
    fn allowance(
        self: @TContractState, owner: starknet::ContractAddress, spender: starknet::ContractAddress
    ) -> u256;
}

#[starknet::contract]
pub mod TestERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        decimals: u8,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, total_supply: u256, decimals: u8) {
        self.decimals.write(decimals);
        self.erc20.mint(starknet::get_caller_address(), total_supply);
    }

    #[abi(embed_v0)]
    impl ITestERC20 of super::ITestERC20<ContractState> {
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn mint(ref self: ContractState, to: starknet::ContractAddress, amount: u256) -> bool {
            self.erc20.mint(to, amount);
            true
        }

        fn mint_to(ref self: ContractState, to: starknet::ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }

        fn burn_from(ref self: ContractState, from: starknet::ContractAddress, amount: u256) {
            self.erc20.burn(from, amount);
        }

        fn approve(ref self: ContractState, spender: starknet::ContractAddress, amount: u256) {
            self.erc20.approve(spender, amount);
        }

        fn burn(ref self: ContractState, amount: u256) {
            self.erc20.burn(starknet::get_caller_address(), amount);
        }

        fn transfer(ref self: ContractState, to: starknet::ContractAddress, amount: u256) {
            self.erc20.transfer(to, amount);
        }

        fn balance_of(self: @ContractState, account: starknet::ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn transfer_from(
            ref self: ContractState,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            amount: u256
        ) -> bool {
            self.erc20.transfer_from(from, to, amount)
        }

        fn allowance(
            self: @ContractState,
            owner: starknet::ContractAddress,
            spender: starknet::ContractAddress
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }
    }
}

#[starknet::interface]
pub trait IXERC20Test<TContractState> {
    fn mint(ref self: TContractState, account: starknet::ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: starknet::ContractAddress, amount: u256);
    fn set_limits(
        ref self: TContractState, address: starknet::ContractAddress, arg1: u256, arg2: u256
    );
    fn owner(self: @TContractState) -> starknet::ContractAddress;
    fn burning_current_limit_of(self: @TContractState, bridge: starknet::ContractAddress) -> u256;
    fn minting_current_limit_of(self: @TContractState, bridge: starknet::ContractAddress) -> u256;
    fn minting_max_limit_of(self: @TContractState, bridge: starknet::ContractAddress) -> u256;
    fn burning_max_limit_of(self: @TContractState, bridge: starknet::ContractAddress) -> u256;
}

#[starknet::contract]
pub mod XERC20Test {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        decimals: u8,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, total_supply: u256, decimals: u8) {
        self.decimals.write(decimals);
        self.erc20.mint(starknet::get_caller_address(), total_supply);
    }

    #[abi(embed_v0)]
    impl IXERC20TestImpl of super::IXERC20Test<ContractState> {
        fn mint(ref self: ContractState, account: starknet::ContractAddress, amount: u256) {
            self.erc20.mint(account, amount);
        }

        fn burn(ref self: ContractState, account: starknet::ContractAddress, amount: u256) {
            self.erc20.burn(account, amount);
        }

        fn set_limits(
            ref self: ContractState, address: starknet::ContractAddress, arg1: u256, arg2: u256
        ) {
            assert!(false);
        }

        fn owner(self: @ContractState) -> starknet::ContractAddress {
            starknet::contract_address_const::<0x0>()
        }

        fn burning_current_limit_of(
            self: @ContractState, bridge: starknet::ContractAddress
        ) -> u256 {
            core::integer::BoundedInt::<u256>::max()
        }

        fn minting_current_limit_of(
            self: @ContractState, bridge: starknet::ContractAddress
        ) -> u256 {
            core::integer::BoundedInt::<u256>::max()
        }

        fn minting_max_limit_of(self: @ContractState, bridge: starknet::ContractAddress) -> u256 {
            core::integer::BoundedInt::<u256>::max()
        }

        fn burning_max_limit_of(self: @ContractState, bridge: starknet::ContractAddress) -> u256 {
            core::integer::BoundedInt::<u256>::max()
        }
    }
}


#[starknet::interface]
pub trait IXERC20LockboxTest<TContractState> {
    fn xerc20(self: @TContractState) -> IXERC20TestDispatcher;
    fn erc20(self: @TContractState) -> ITestERC20Dispatcher;
    fn deposit_to(ref self: TContractState, user: starknet::ContractAddress, amount: u256);
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw_to(ref self: TContractState, user: starknet::ContractAddress, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
}

#[starknet::contract]
pub mod XERC20LockboxTest {
    use starknet::ContractAddress;
    use super::{
        ITestERC20Dispatcher, ITestERC20DispatcherTrait, IXERC20TestDispatcher,
        IXERC20TestDispatcherTrait
    };

    #[storage]
    struct Storage {
        XERC20: IXERC20TestDispatcher,
        ERC20: ITestERC20Dispatcher,
    }

    #[constructor]
    fn constructor(ref self: ContractState, xerc20: ContractAddress, erc20: ContractAddress) {
        self.XERC20.write(IXERC20TestDispatcher { contract_address: xerc20 });
        self.ERC20.write(ITestERC20Dispatcher { contract_address: erc20 });
    }

    impl IXERC20LockboxTest of super::IXERC20LockboxTest<ContractState> {
        fn xerc20(self: @ContractState) -> IXERC20TestDispatcher {
            self.XERC20.read()
        }

        fn erc20(self: @ContractState) -> ITestERC20Dispatcher {
            self.ERC20.read()
        }

        fn deposit_to(ref self: ContractState, user: starknet::ContractAddress, amount: u256) {
            self
                .ERC20
                .read()
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount
                );
            self.XERC20.read().mint(user, amount);
        }
        fn deposit(ref self: ContractState, amount: u256) {
            self.deposit_to(starknet::get_caller_address(), amount);
        }

        fn withdraw_to(ref self: ContractState, user: starknet::ContractAddress, amount: u256) {
            self.XERC20.read().burn(starknet::get_caller_address(), amount);
            self.ERC20.read().mint_to(user, amount);
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            self.withdraw_to(starknet::get_caller_address(), amount);
        }
    }
}
