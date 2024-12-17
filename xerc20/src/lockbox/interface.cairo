use starknet::ContractAddress;

#[starknet::interface]
pub trait IXERC20Lockbox<TState> {
    fn deposit(ref self: TState, amount: u256);
    fn deposit_to(ref self: TState, to: ContractAddress, amount: u256);
    fn withdraw(ref self: TState, amount: u256);
    fn withdraw_to(ref self: TState, to: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IXERC20LockboxGetters<TState> {
    fn xerc20(self: @TState) -> ContractAddress;
    fn erc20(self: @TState) -> ContractAddress;
}

#[starknet::interface]
pub trait XERC20LockboxABI<TState> {
    /// IXERC20Lockbox
    fn deposit(ref self: TState, amount: u256);
    fn deposit_to(ref self: TState, to: ContractAddress, amount: u256);
    fn withdraw(ref self: TState, amount: u256);
    fn withdraw_to(ref self: TState, to: ContractAddress, amount: u256);
    /// IXERC20LockboxGetters
    fn xerc20(self: @TState) -> ContractAddress;
    fn erc20(self: @TState) -> ContractAddress;
}
