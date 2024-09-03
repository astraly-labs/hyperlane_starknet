#[starknet::interface]
pub trait IHypFiatToken<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypFiatToken {
    #[storage]
    struct Storage {
        fiat_token: u256,
        mailbox: u256,
    }

    fn constructor() {}

    impl HypFiatTokenImpl of super::IHypFiatToken<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, amount: u256) -> u256 {
            0
        }

        fn transfer_to(ref self: ContractState, recipient: u256, amount: u256, metadata: u256) {}
    }
}
