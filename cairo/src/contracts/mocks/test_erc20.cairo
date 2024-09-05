#[starknet::interface]
pub trait ITestERC20<TContractState> {
    fn decimals(self: @TContractState) -> u8;
    fn _mint(ref self: TContractState, amount: u256);
    fn mint_to(ref self: TContractState, to: starknet::ContractAddress, amount: u256);
    fn burn_from(ref self: TContractState, from: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod TestERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

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

        fn _mint(ref self: ContractState, amount: u256) {
            self.erc20.mint(starknet::get_caller_address(), amount);
        }

        fn mint_to(ref self: ContractState, to: starknet::ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }

        fn burn_from(ref self: ContractState, from: starknet::ContractAddress, amount: u256) {
            self.erc20.burn(from, amount);
        }
    }
}
