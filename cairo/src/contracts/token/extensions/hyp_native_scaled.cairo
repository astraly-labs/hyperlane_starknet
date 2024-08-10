#[starknet::interface]
pub trait IHypNativeScaled<TState> {
    fn initialize(ref self: TState);
    fn transfer_remote(self: @TState, destination: u32, recipient: u256, amount: u256) -> u256;
    fn balance_of(self: @TState, account: u256) -> u256;
}

#[starknet::contract]
pub mod HypNativeScaled {
    #[storage]
    struct Storage {
        scale: u256,
        mailbox: u256,
    }

    fn constructor() {}

    impl HypNativeScaledImpl of super::IHypNativeScaled<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn transfer_remote(
            self: @ContractState, destination: u32, recipient: u256, amount: u256
        ) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: u256) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_to(ref self: ContractState, recipient: u256, amount: u256, metadata: u256) {}
    }
}
