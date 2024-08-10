#[starknet::interface]
pub trait IHypERC721URIStorage<TState> {
    fn initialize(ref self: TState);
    fn balance_of(self: @TState, account: u256) -> u256;
    fn token_uri(self: @TState, token_id: u256) -> u256;
    fn supports_interface(self: @TState, interface_id: u256) -> bool;
}

#[starknet::contract]
pub mod HypERC721URIStorage {
    #[storage]
    struct Storage {
        mailbox: u256,
    }

    fn constructor() {}

    impl HypERC721URIStorageImpl of super::IHypERC721URIStorage<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn balance_of(self: @ContractState, account: u256) -> u256 {
            0
        }

        fn token_uri(self: @ContractState, token_id: u256) -> u256 {
            0
        }

        fn supports_interface(self: @ContractState, interface_id: u256) -> bool {
            false
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn transfer_from_sender(ref self: ContractState, token_id: u256) -> u256 {
            0
        }

        fn transfer_to(ref self: ContractState, recipient: u256, token_id: u256, token_uri: u256) {}

        fn before_token_transfer(
            ref self: ContractState, from: u256, to: u256, token_id: u256, batch_size: u256
        ) {}

        fn burn(ref self: ContractState, token_id: u256) {}
    }
}
