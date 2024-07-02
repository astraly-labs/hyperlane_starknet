use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use hyperlane_starknet::utils::keccak256::{
    reverse_endianness, compute_keccak, ByteData, u256_word_size, u64_word_size, ADDRESS_SIZE
};
use starknet::{ContractAddress, contract_address_const};

pub const HYPERLANE_VERSION: u8 = 3;


#[derive(Serde, starknet::Store, Drop, Clone)]
pub struct Message {
    pub version: u8,
    pub nonce: u32,
    pub origin: u32,
    pub sender: u256,
    pub destination: u32,
    pub recipient: u256,
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
            sender: 0,
            destination: 0_u32,
            recipient: 0,
            body: BytesTrait::new_empty(),
        }
    }

    /// Format an input message, using 
    /// 
    /// # Arguments
    /// 
    /// * `_message` - Message to hash
    /// 
    ///  # Returns
    /// 
    /// * u256 representing the hash of the message
    fn format_message(_message: Message) -> (u256, Message) {
        let mut input: Array<ByteData> = array![
            ByteData {
                value: _message.version.into(), size: u64_word_size(_message.version.into()).into()
            },
            ByteData {
                value: _message.nonce.into(), size: u64_word_size(_message.nonce.into()).into()
            },
            ByteData {
                value: _message.origin.into(), size: u64_word_size(_message.origin.into()).into()
            },
            ByteData { value: _message.sender.into(), size: ADDRESS_SIZE },
            ByteData {
                value: _message.destination.into(),
                size: u64_word_size(_message.destination.into()).into()
            },
            ByteData { value: _message.recipient.into(), size: ADDRESS_SIZE },
            ByteData {
                value: _message.body.size().into(),
                size: u64_word_size(_message.body.size().into()).into()
            },
        ];

        let mut message_data = _message.clone().body.data();
        loop {
            match message_data.pop_front() {
                Option::Some(data) => {
                    input
                        .append(
                            ByteData {
                                value: data.into(), size: u256_word_size(data.into()).into()
                            }
                        );
                },
                Option::None(_) => { break (); }
            };
        };
        (reverse_endianness(compute_keccak(input.span())), _message)
    }
}
