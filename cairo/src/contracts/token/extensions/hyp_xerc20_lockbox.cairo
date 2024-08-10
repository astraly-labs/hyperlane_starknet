#[starknet::interface]
pub trait IHypXERC20Lockbox<TState> {
    fn initialize(ref self: TState, hook: u256, ism: u256, owner: u256);
    fn approve_lockbox(ref self: TState);
    fn balance_of(self: @TState) -> u256;
}

#[starknet::contract]
pub mod HypXERC20Lockbox {
    #[storage]
    struct Storage {
        lockbox: u256,
        xerc20: u256,
        wrapped_token: u256,
        mailbox: u256,
    }

    fn constructor() {}

    impl HypXERC20LockboxImpl of super::IHypXERC20Lockbox<ContractState> {
        fn initialize(ref self: ContractState, hook: u256, ism: u256, owner: u256) {}

        fn approve_lockbox(ref self: ContractState) {}

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
