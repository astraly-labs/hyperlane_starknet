use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
pub struct Bridge {
    pub minter_params: BridgeParameters,
    pub burner_params: BridgeParameters,
}

#[derive(Drop, Serde, Copy)]
pub struct BridgeParameters {
    pub max_limit: u256,
    pub current_limit: u256,
    pub timestamp: u64,
    pub rate_per_second: u256,
}

#[starknet::interface]
pub trait IXERC20<TState> {
    fn set_lockbox(ref self: TState, lockbox: ContractAddress);
    fn set_limits(
        ref self: TState, bridge: ContractAddress, minting_limit: u256, burning_limit: u256,
    );
    fn mint(ref self: TState, user: ContractAddress, amount: u256);
    fn burn(ref self: TState, user: ContractAddress, amount: u256);
    fn minting_max_limit_of(self: @TState, minter: ContractAddress) -> u256;
    fn burning_max_limit_of(self: @TState, bridge: ContractAddress) -> u256;
    fn minting_current_limit_of(self: @TState, minter: ContractAddress) -> u256;
    fn burning_current_limit_of(self: @TState, bridge: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IXERC20Getters<TState> {
    fn lockbox(self: @TState) -> ContractAddress;
    fn factory(self: @TState) -> ContractAddress;
    fn get_bridge(self: @TState, bridge: ContractAddress) -> Bridge;
}

#[starknet::interface]
pub trait XERC20ABI<TState> {
    /// IXERC20
    fn set_lockbox(ref self: TState, lockbox: ContractAddress);
    fn set_limits(
        ref self: TState, bridge: ContractAddress, minting_limit: u256, burning_limit: u256,
    );
    fn mint(ref self: TState, user: ContractAddress, amount: u256);
    fn burn(ref self: TState, user: ContractAddress, amount: u256);
    fn minting_max_limit_of(self: @TState, minter: ContractAddress) -> u256;
    fn burning_max_limit_of(self: @TState, bridge: ContractAddress) -> u256;
    fn minting_current_limit_of(self: @TState, minter: ContractAddress) -> u256;
    fn burning_current_limit_of(self: @TState, bridge: ContractAddress) -> u256;
    /// IXERC20Getters
    fn lockbox(self: @TState) -> ContractAddress;
    fn factory(self: @TState) -> ContractAddress;
    fn get_bridge(self: @TState, bridge: ContractAddress) -> Bridge;
}
