#[starknet::interface]
pub trait IHypXERC20<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypXERC20 {
    #[storage]
    struct Storage {
        xerc20: u256,
        mailbox: u256,
    }

    fn constructor() {}

    impl HypXERC20Impl of super::IHypXERC20<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, amount_or_id: u256) -> u256 {
            0
        }

        fn transfer_to(
            ref self: ContractState, recipient: u256, amount_or_id: u256, metadata: u256
        ) {}
    }
}
