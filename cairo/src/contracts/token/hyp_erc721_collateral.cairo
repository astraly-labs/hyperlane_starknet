#[starknet::interface]
pub trait IHypErc721Collateral<TState> {
    fn initialize(ref self: TState);
    fn owner_of(self: @TState, token_id: u256) -> u256;
    fn balance_of(self: @TState, account: u256) -> u256;
}

#[starknet::contract]
pub mod HypErc721Collateral {
    #[storage]
    struct Storage {
        wrapped_token: u256,
    }

    fn constructor() {}

    impl HypErc721CollateralImpl of super::IHypErc721Collateral<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn owner_of(self: @ContractState, token_id: u256) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: u256) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, token_id: u256) {}

        fn transfer_to_recipient(ref self: ContractState, recipient: u256, token_id: u256) {}
    }
}
