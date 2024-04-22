use alexandria_bytes::Bytes;
use hyperlane_starknet::contracts::libs::message::Message;
use starknet::ContractAddress;

#[derive(Serde)]
pub enum Types {
    UNUSED,
    ROUTING,
    AGGREGATION,
    MERKLE_TREE,
    INTERCHAIN_GAS_PAYMASTER,
    FALLBACK_ROUTING,
    ID_AUTH_ISM,
    PAUSABLE,
    PROTOCOL_FEE,
    LAYER_ZERO_V1,
    Rate_Limited_Hook
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

pub const HYPERLANE_VERSION: u8 = 3;

#[starknet::interface]
pub trait IMailbox<TContractState> {
    fn initializer(
        ref self: TContractState,
        _default_ism: ContractAddress,
        _default_hook: ContractAddress,
        _required_hook: ContractAddress
    );

    fn get_local_domain(self: @TContractState) -> u32;

    fn delivered(self: @TContractState, _message_id: felt252) -> bool;

    fn get_default_ism(self: @TContractState) -> ContractAddress;

    fn get_default_hook(self: @TContractState) -> ContractAddress;

    fn get_required_hook(self: @TContractState) -> ContractAddress;

    fn get_latest_dispatched_id(self: @TContractState) -> Bytes;

    fn dispatch(
        ref self: TContractState,
        _destination_domain: u32,
        _recipient_address: ContractAddress,
        _message_body: Bytes,
        _custom_hook_metadata: Option<Bytes>,
        _custom_hook: Option<ContractAddress>,
    ) -> Bytes;

    fn quote_dispatch(
        ref self: TContractState,
        _destination_domain: u32,
        _recipient_address: ContractAddress,
        _message_body: Bytes,
        _custom_hook_metadata: Option<Bytes>,
        _custom_hook: Option<ContractAddress>,
    ) -> u256;

    fn process(ref self: TContractState, _metadata: Bytes, _message: Message,);

    fn recipient_ism(ref self: TContractState, _recipient: ContractAddress) -> ContractAddress;

    fn set_default_ism(ref self: TContractState, _module: ContractAddress);

    fn set_default_hook(ref self: TContractState, _hook: ContractAddress);

    fn set_required_hook(ref self: TContractState, _hook: ContractAddress);

    fn set_local_domain(ref self: TContractState, _local_domain: u32);
}


#[starknet::interface]
pub trait IInterchainSecurityModule<TContractState> {
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
    fn verify(self: @TContractState, _metadata: Bytes, _message: Message) -> bool;
}

#[starknet::interface]
pub trait ISpecifiesInterchainSecurityModule<TContractState> {
    fn interchain_security_module(self: @TContractState) -> ContractAddress;
}


#[starknet::interface]
pub trait IPostDispatchHook<TContractState> {
    fn get_hook_type(self: @TContractState) -> Types;

    fn supports_metadata(self: @TContractState, _metadata: Bytes) -> bool;

    fn post_dispatch(ref self: TContractState, _metadata: Bytes, _message: Bytes);

    fn quote_dispatch(ref self: TContractState, _metadata: Bytes, _message: Bytes) -> u256;
}



#[starknet::interface]
pub trait IMessageRecipient<TContractState>{
    fn handle(self: @TContractState, origin: u32, _sender: ContractAddress, _message: Bytes);
}