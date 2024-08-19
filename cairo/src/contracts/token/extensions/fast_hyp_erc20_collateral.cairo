#[starknet::interface]
pub trait IFastHypERC20<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState, account: u256) -> u256;
}

// Since this contract inherits form HyerErc20, to avoid having it as component,
// we need to reimplement all the methods of the IHyerErc20 trait.
#[starknet::contract]
pub mod FastHypERC20Collateral {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl FastHypERC20Impl of super::IFastHypERC20<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState, account: u256) -> u256 {
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
