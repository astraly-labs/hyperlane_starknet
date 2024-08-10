#[starknet::interface]
pub trait IHypErc721<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypErc721 {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl HypErc721Impl of super::IHypErc721<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, token_id: u256) {}

        fn transfer_to_recipient(ref self: ContractState, recipient: u256, token_id: u256) {}
    }
}

