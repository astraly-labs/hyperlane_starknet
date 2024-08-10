#[starknet::interface]
pub mod IHypErc20<TState> {
    fn initialize(ref self: TState);
    fn decimals() -> u8;
    fn balance_of(ref self: TState) -> Uint256;
}

#[starknet::contract]
pub mod HypErc20 {

    #[storage]
    struct Storage {}

    fn constructor() {}

    impl HypErc20Impl of super::IHypErc20<ContractState> {
        fn initialize() {}

    fn decimals() -> u8 {0}

    fn balance_of(ref self: ContractState) -> Uint256 {0}
    }
}