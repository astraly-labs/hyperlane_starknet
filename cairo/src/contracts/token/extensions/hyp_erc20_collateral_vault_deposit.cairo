#[starknet::interface]
pub trait IHypERC20CollateralVaultDeposit<TState> {
    fn initialize(ref self: TState);
    fn sweep(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypERC20CollateralVaultDeposit {
    #[storage]
    struct Storage {
        vault: u256,
        asset_deposited: u256,
    }

    fn constructor() {}

    impl HypERC20CollateralVaultDepositImpl of super::IHypERC20CollateralVaultDeposit<
        ContractState
    > {
        fn initialize(ref self: ContractState) {}

        fn sweep(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn deposit_into_vault(ref self: ContractState, amount: u256) {}

        fn withdraw_from_vault(ref self: ContractState, amount: u256, recipient: u256) {}

        fn transfer_from_sender(ref self: ContractState, amount: u256) -> u256 {
            0
        }

        fn transfer_to(ref self: ContractState, recipient: u256, amount: u256) {}
    }
}
