#[starknet::interface]
pub trait IHypErc20<TState> {
    fn initialize(ref self: TState);
    fn decimals(self: @TState) -> u8;
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypErc20 {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl HypErc20Impl of super::IHypErc20<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn decimals(self: @ContractState) -> u8 {
            0
        }

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternaImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState) {}

        fn transfer_to_recipient(ref self: ContractState) {}
    }
}
