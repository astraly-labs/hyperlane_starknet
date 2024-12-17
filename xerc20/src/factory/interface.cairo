use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IXERC20Factory<TState> {
    fn deploy_xerc20(
        ref self: TState,
        name: ByteArray,
        symbol: ByteArray,
        minter_limits: Span<u256>,
        burner_limits: Span<u256>,
        bridges: Span<ContractAddress>,
    ) -> ContractAddress;
    fn deploy_lockbox(
        ref self: TState, xerc20: ContractAddress, base_token: ContractAddress,
    ) -> ContractAddress;
    // Setters
    fn set_xerc20_class_hash(ref self: TState, new_class_hash: ClassHash);
    fn set_lockbox_class_hash(ref self: TState, new_class_hash: ClassHash);
    // Getters
    fn get_xerc20_class_hash(self: @TState) -> ClassHash;
    fn get_lockbox_class_hash(self: @TState) -> ClassHash;
    fn get_xerc20s(self: @TState) -> Array<ContractAddress>;
    fn get_lockboxes(self: @TState) -> Array<ContractAddress>;
    fn get_lockbox_for_erc20(self: @TState, erc20: ContractAddress) -> ContractAddress;
    fn is_lockbox(self: @TState, lockbox: ContractAddress) -> bool;
    fn is_xerc20(self: @TState, xerc20: ContractAddress) -> bool;
}
