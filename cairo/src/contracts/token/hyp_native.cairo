#[starknet::interface]
pub trait IHypNative<TState> {
    fn initialize(ref self: TState);
    fn transfer_remote(ref self: TState, destination: u32, recipient: u256, amount: u256) -> u256;
    fn balance_of(self: @TState, account: u256) -> u256;
}

#[starknet::contract]
pub mod HypNative {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl HypNativeImpl of super::IHypNative<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn transfer_remote(
            ref self: ContractState, destination: u32, recipient: u256, amount: u256
        ) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: u256) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, amount: u256) -> u256 {
            0
        }

        fn transfer_to_recipient(ref self: ContractState, recipient: u256, amount: u256) {}
    }
}
