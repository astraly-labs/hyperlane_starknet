#[starknet::interface]
pub trait IFastHypERC20Collateral<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod FastHypERC20Collateral {
    #[storage]
    struct Storage {
        wrapped_token: u256,
        mailbox: u256,
    }

    fn constructor() {}

    impl FastHypERC20CollateralImpl of super::IFastHypERC20Collateral<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn handle(ref self: ContractState, origin: u32, sender: u256, message: u256) {}

        fn fast_transfer_to(ref self: ContractState, recipient: u256, amount: u256) {}

        fn fast_receive_from(ref self: ContractState, sender: u256, amount: u256) {}
    }
}
