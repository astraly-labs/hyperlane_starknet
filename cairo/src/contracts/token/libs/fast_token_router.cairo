#[starknet::interface]
pub trait IFastTokenRouter<TState> {
    fn initialize(ref self: TState);
    fn fill_fast_transfer(
        ref self: TState,
        recipient: u256,
        amount: u256,
        fast_fee: u256,
        origin: u32,
        fast_transfer_id: u256
    );
    fn fast_transfer_remote(
        ref self: TState, destination: u32, recipient: u256, amount_or_id: u256, fast_fee: u256
    ) -> u256;
}

#[starknet::contract]
pub mod FastTokenRouter {
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl FastTokenRouterImpl of super::IFastTokenRouter<ContractState> {
        fn initialize(ref self: ContractState) {}

        fn fill_fast_transfer(
            ref self: ContractState,
            recipient: u256,
            amount: u256,
            fast_fee: u256,
            origin: u32,
            fast_transfer_id: u256
        ) {}

        fn fast_transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            fast_fee: u256
        ) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn handle(self: @ContractState, origin: u32, message: u256) {}

        fn fast_transfer_to(ref self: ContractState, recipient: u256, amount: u256) {}

        fn fast_recieve_from(ref self: ContractState, sender: u256, amount: u256) {}

        fn get_token_recipient(
            self: @ContractState, recipient: u256, amount: u256, origin: u32, metadata: u256
        ) -> u256 {
            0
        }

        fn get_fast_transfers_key(
            self: @ContractState,
            origin: u32,
            fast_transfer_id: u256,
            amount: u256,
            fast_fee: u256,
            recipient: u256
        ) -> u256 {
            0
        }

        fn fast_transfer_from_sender(
            ref self: ContractState, amount: u256, fast_fee: u256, fast_transfer_id: u256
        ) -> u256 {
            0
        }
    }
}
