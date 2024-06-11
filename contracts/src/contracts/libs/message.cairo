use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use core::poseidon::poseidon_hash_span;
use hyperlane_starknet::utils::keccak256::{reverse_endianness, compute_keccak, ByteData};
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
            version: HYPERLANE_VERSION,
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
    fn format_message(_message: Message) -> (u256, Message) {
        let sender: felt252 = _message.sender.into();
        let recipient: felt252 = _message.recipient.into();

        let mut input: Array<ByteData> = array![
            ByteData { value: _message.version.into(), is_address: false },
            ByteData { value: _message.origin.into(), is_address: false },
            ByteData { value: sender.into(), is_address: true },
            ByteData { value: _message.destination.into(), is_address: false },
            ByteData { value: recipient.into(), is_address: true },
            ByteData { value: _message.body.size().into(), is_address: false },
        ];
        let mut message_data = _message.clone().body.data();
        loop {
            match message_data.pop_front() {
                Option::Some(data) => {
                    input.append(ByteData { value: data.into(), is_address: false });
                },
                Option::None(_) => { break (); }
            };
        };
        (compute_keccak(input.span()), _message)
    }
}
