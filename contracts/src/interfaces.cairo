use alexandria_bytes::Bytes;
use core::array::ArrayTrait;
use hyperlane_starknet::contracts::libs::merkle_lib::merkle_lib::Tree;
use hyperlane_starknet::contracts::libs::message::Message;
use starknet::ContractAddress;
use starknet::EthAddress;

#[derive(Serde, Drop)]
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


#[derive(Serde, Drop, PartialEq)]
pub enum ModuleType {
    UNUSED: ContractAddress,
    ROUTING: ContractAddress,
    AGGREGATION: ContractAddress,
    LEGACY_MULTISIG: ContractAddress,
    MERKLE_ROOT_MULTISIG: ContractAddress,
    MESSAGE_ID_MULTISIG: ContractAddress,
    NULL, // used with relayer carrying no metadata
    CCIP_READ: ContractAddress,
}


#[starknet::interface]
pub trait IMailbox<TContractState> {
    fn initializer(
        ref self: TContractState,
        _default_ism: ContractAddress,
        _default_hook: ContractAddress,
        _required_hook: ContractAddress
    );

    fn get_local_domain(self: @TContractState) -> u32;

    fn delivered(self: @TContractState, _message_id: u256) -> bool;

    fn nonce(self: @TContractState) -> u32;

    fn get_default_ism(self: @TContractState) -> ContractAddress;

    fn get_default_hook(self: @TContractState) -> ContractAddress;

    fn get_required_hook(self: @TContractState) -> ContractAddress;

    fn get_latest_dispatched_id(self: @TContractState) -> u256;

    fn dispatch(
        ref self: TContractState,
        _destination_domain: u32,
        _recipient_address: ContractAddress,
        _message_body: Bytes,
        _custom_hook_metadata: Option<Bytes>,
        _custom_hook: Option<ContractAddress>,
    ) -> u256;

    fn quote_dispatch(
        self: @TContractState,
        _destination_domain: u32,
        _recipient_address: ContractAddress,
        _message_body: Bytes,
        _custom_hook_metadata: Option<Bytes>,
        _custom_hook: Option<ContractAddress>,
    ) -> u256;

    fn process(ref self: TContractState, _metadata: Bytes, _message: Message,);

    fn recipient_ism(self: @TContractState, _recipient: ContractAddress) -> ContractAddress;

    fn set_default_ism(ref self: TContractState, _module: ContractAddress);

    fn set_default_hook(ref self: TContractState, _hook: ContractAddress);

    fn set_required_hook(ref self: TContractState, _hook: ContractAddress);

    fn set_local_domain(ref self: TContractState, _local_domain: u32);

    fn processor(self: @TContractState, _id: u256) -> ContractAddress;

    fn processed_at(self: @TContractState, _id: u256) -> u64;
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
    fn verify(self: @TContractState, _metadata: Bytes, _message: Message,) -> bool;

    fn validators_and_threshold(
        self: @TContractState, _message: Message
    ) -> (Span<EthAddress>, u32);

    fn get_validators(self: @TContractState) -> Span<EthAddress>;

    fn get_threshold(self: @TContractState) -> u32;

    fn set_validators(ref self: TContractState, _validators: Span<EthAddress>);

    fn set_threshold(ref self: TContractState, _threshold: u32);
}

#[starknet::interface]
pub trait ISpecifiesInterchainSecurityModule<TContractState> {
    fn interchain_security_module(self: @TContractState) -> ModuleType;
}


#[starknet::interface]
pub trait IPostDispatchHook<TContractState> {
    fn get_hook_type(self: @TContractState) -> Types;

    fn supports_metadata(self: @TContractState, _metadata: Bytes) -> bool;

    fn post_dispatch(ref self: TContractState, _metadata: Bytes, _message: Message);

    fn quote_dispatch(ref self: TContractState, _metadata: Bytes, _message: Message) -> u256;
}


#[starknet::interface]
pub trait IMessageRecipient<TContractState> {
    fn handle(ref self: TContractState, _origin: u32, _sender: ContractAddress, _message: Bytes);

    fn get_origin(self: @TContractState) -> u32;

    fn get_sender(self: @TContractState) -> ContractAddress;

    fn get_message(self: @TContractState) -> Bytes;
}


#[starknet::interface]
pub trait IMailboxClient<TContractState> {
    fn set_hook(ref self: TContractState, _hook: ContractAddress);

    fn set_interchain_security_module(ref self: TContractState, _module: ContractAddress);

    fn _MailboxClient_initialize(
        ref self: TContractState,
        _hook: ContractAddress,
        _interchain_security_module: ContractAddress,
    );

    fn get_hook(self: @TContractState) -> ContractAddress;

    fn get_local_domain(self: @TContractState) -> u32;

    fn get_interchain_security_module(self: @TContractState) -> ContractAddress;

    fn _is_latest_dispatched(self: @TContractState, _id: u256) -> bool;

    fn _is_delivered(self: @TContractState, _id: u256) -> bool;

    fn _dispatch(
        self: @TContractState,
        _destination_domain: u32,
        _recipient: ContractAddress,
        _message_body: Bytes,
        _hook_metadata: Option<Bytes>,
        _hook: Option<ContractAddress>
    ) -> u256;

    fn quote_dispatch(
        self: @TContractState,
        _destination_domain: u32,
        _recipient: ContractAddress,
        _message_body: Bytes,
        _hook_metadata: Option<Bytes>,
        _hook: Option<ContractAddress>
    ) -> u256;
}


#[starknet::interface]
pub trait IInterchainGasPaymaster<TContractState> {
    fn pay_for_gas(
        ref self: TContractState,
        _message_id: u256,
        _destination_domain: u32,
        _gas_amount: u256,
        _payment: u256
    );

    fn quote_gas_payment(
        ref self: TContractState, _destination_domain: u32, _gas_amount: u256
    ) -> u256;
}

#[starknet::interface]
pub trait IRouter<TContractState> {
    fn routers(self: @TContractState, _domain: u32) -> ContractAddress;

    fn unenroll_remote_router(ref self: TContractState, _domain: u32);

    fn enroll_remote_router(ref self: TContractState, _domain: u32, _router: ContractAddress);

    fn enroll_remote_routers(
        ref self: TContractState, _domains: Span<u32>, _routers: Span<ContractAddress>
    );

    fn unenroll_remote_routers(ref self: TContractState, _domains: Span<u32>);

    fn handle(self: @TContractState, _origin: u32, _sender: ContractAddress, _message: Message);
}


#[starknet::interface]
pub trait IDefaultFallbackRoutingIsm<TContractState> {
    /// Returns an enum that represents the type of security model encoded by this ISM.
    /// Relayers infer how to fetch and format metadata.
    fn module_type(self: @TContractState) -> ModuleType;

    fn route(self: @TContractState, _message: Message) -> ContractAddress;

    fn verify(self: @TContractState, _metadata: Bytes, _message: Message) -> bool;
}

#[starknet::interface]
pub trait IDomainRoutingIsm<TContractState> {
    fn initialize(ref self: TContractState, _domains: Span<u32>, _modules: Span<ContractAddress>);

    fn set(ref self: TContractState, _domain: u32, _module: ContractAddress);

    fn remove(ref self: TContractState, _domain: u32);

    fn domains(self: @TContractState) -> Span<u32>;

    fn module(self: @TContractState, _origin: u32) -> ContractAddress;

    fn route(self: @TContractState, _message: Message) -> ContractAddress;
}


#[starknet::interface]
pub trait IValidatorAnnounce<TContractState> {
    fn get_announced_validators(self: @TContractState) -> Span<EthAddress>;

    fn get_announced_storage_locations(
        self: @TContractState, _validators: Span<EthAddress>
    ) -> Span<Span<felt252>>;

    fn announce(
        ref self: TContractState,
        _validator: EthAddress,
        _storage_location: Array<felt252>,
        _signature: Bytes
    ) -> bool;

    fn get_announcement_digest(self: @TContractState, _storage_location: Array<u256>) -> u256;
}

#[starknet::interface]
pub trait IAggregation<TContractState> {
    fn module_type(self: @TContractState) -> ModuleType;

    fn modules_and_threshold(
        self: @TContractState, _message: Message
    ) -> (Span<ContractAddress>, u8);

    fn verify(self: @TContractState, _metadata: Bytes, _message: Message,) -> bool;

    fn get_modules(self: @TContractState) -> Span<ContractAddress>;

    fn get_threshold(self: @TContractState) -> u8;

    fn set_modules(ref self: TContractState, _modules: Span<ContractAddress>);

    fn set_threshold(ref self: TContractState, _threshold: u8);
}


#[starknet::interface]
pub trait IMerkleTreeHook<TContractState> {
    fn count(self: @TContractState) -> u32;

    fn root(self: @TContractState) -> u256;

    fn tree(self: @TContractState) -> Tree;

    fn latest_checkpoint(self: @TContractState) -> (u256, u32);

    fn hook_type(self: @TContractState) -> Types;
}
