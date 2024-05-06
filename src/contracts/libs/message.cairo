use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use core::keccak::keccak_u256s_be_inputs;
use core::poseidon::poseidon_hash_span;
use hyperlane_starknet::utils::keccak256::reverse_endianness;
use starknet::{ContractAddress, contract_address_const};

pub const HYPERLANE_VERSION: u8 = 3;


#[derive(Serde, starknet::Store, Drop, Clone)]
pub struct Message {
    pub version: u8,
    pub nonce: u32,
    pub origin: u32,
    pub sender: ContractAddress,
    pub destination: u32,
    pub recipient: ContractAddress,
    pub body: Bytes,
}


#[generate_trait]
pub impl MessageImpl of MessageTrait {
    /// Generate a default empty message
    /// 
    ///  # Returns
    /// 
    /// * An empty message structure
    fn default() -> Message {
        Message {
            version: 3_u8,
            nonce: 0_u32,
            origin: 0_u32,
            sender: contract_address_const::<0>(),
            destination: 0_u32,
            recipient: contract_address_const::<0>(),
            body: BytesTrait::new_empty(),
        }
    }

    /// Format an input message, using reverse keccak big endian
    /// 
    /// # Arguments
    /// 
    /// * `_message` - Message to hash
    /// 
    ///  # Returns
    /// 
    /// * u256 representing the hash of the message
    fn format_message(_message: Message) -> u256 {
        let sender: felt252 = _message.sender.into();
        let recipient: felt252 = _message.recipient.into();

        let mut input: Array<u256> = array![
            _message.version.into(),
            _message.origin.into(),
            sender.into(),
            _message.destination.into(),
            recipient.into(),
            _message.body.size().into()
        ];
        let mut message_data = _message.body.data();
        loop {
            match message_data.pop_front() {
                Option::Some(data) => { input.append(data.into()); },
                Option::None(_) => { break (); }
            };
        };
        let hash = keccak_u256s_be_inputs(input.span());
        reverse_endianness(hash)
    }
}
