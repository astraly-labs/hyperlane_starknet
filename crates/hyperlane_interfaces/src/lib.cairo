use alexandria_bytes::Bytes;
use starknet::ContractAddress;

#[starknet::interface]
trait IMailbox<TContractState> {
    fn local_domain(self: @TContractState) -> u32;

    fn delivered(self: @TContractState, message_id: Bytes) -> bool;

    fn default_ism(self: @TContractState) -> ContractAddress;

    fn default_hook(self: @TContractState) -> ContractAddress;

    fn required_hook(self: @TContractState) -> ContractAddress;

    fn latest_dispatched_id(self: @TContractState) -> Bytes;

    fn dispatch(
        ref self: TContractState,
        destination_domain: u32,
        recipient_address: Bytes,
        message_body: Bytes,
        custom_hook_metadata: Option<Bytes>,
        custom_hook: Option<ContractAddress>,
    ) -> Bytes;

    fn quote_dispatch(
        ref self: TContractState,
        destination_domain: u32,
        recipient_address: Bytes,
        message_body: Bytes,
        custom_hook_metadata: Option<Bytes>,
        custom_hook: Option<ContractAddress>,
    ) -> u256;

    fn process(ref self: TContractState, metadata: Bytes, message: Bytes,);

    fn recipient_ism(ref self: TContractState, recipient: ContractAddress) -> ContractAddress;
}

#[derive(Serde)]
pub enum ModuleType {
    UNUSED,
    ROUTING,
    AGGREGATION,
    LEGACY_MULTISIG,
    MERKLE_ROOT_MULTISIG,
    MESSAGE_ID_MULTISIG,
    NULL, // used with relayer carrying no metadata
    CCIP_READ,
}

#[starknet::interface]
trait IInterchainSecurityModule<TContractState> {
    /// Returns an enum that represents the type of security model encoded by this ISM.
    /// Relayers infer how to fetch and format metadata.
    fn module_type(self: @TContractState) -> ModuleType;

    /// Defines a security model responsible for verifying interchain messages based on the provided metadata.
    /// Returns true if the message was verified.
    /// 
    /// # Arguments
    /// * `_metadata` - Off-chain metadata provided by a relayer, specific to the security model encoded by 
    /// the module (e.g. validator signatures)
    /// * `_message` - Hyperlane encoded interchain message
    fn verify(self: @TContractState, metadata: Bytes, message: Bytes) -> bool;
}

#[starknet::interface]
trait ISpecifiesInterchainSecurityModule<TContractState> {
    fn interchain_security_module(self: @TContractState) -> ContractAddress;
}
