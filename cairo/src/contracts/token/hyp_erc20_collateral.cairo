#[starknet::interface]
pub trait IHypErc20Collateral<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypErc20 {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl HypErc20CollateralImpl of super::IHypErc20Collateral<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternaImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState) {}

        fn transfer_to(ref self: ContractState) {}
    }
}
