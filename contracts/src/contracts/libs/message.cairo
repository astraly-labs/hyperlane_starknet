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
        let sender: felt252 = _message.sender.into();
        let recipient: felt252 = _message.recipient.into();

        let mut input: Array<ByteData> = array![
            ByteData { value: _message.version.into(), size: 1 },
            ByteData { value: _message.nonce.into(), size: 4 },
            ByteData { value: _message.origin.into(), size: 4 },
            ByteData { value: sender.into(), size: 32 },
            ByteData { value: _message.destination.into(), size: 4 },
            ByteData { value: recipient.into(), size: 32 },
        ];
        let message_data = _message.clone().body.data();
        let finalized_input = MessageImpl::append_span_u128_to_byte_data(input, message_data.span(), _message.clone().body.size());
        (reverse_endianness(compute_keccak(finalized_input)), _message)
    }

    fn append_span_u128_to_byte_data(mut _input: Array<ByteData>, _to_append: Span<u128>, size: u32) -> Span<ByteData>{
        let mut cur_idx = 0;
        let range = size /16;
        loop {
            if (cur_idx == range)
            {
                if (size % 16 == 0){
                    break;
                } else {
                    _input
                        .append(
                            ByteData {
                                value: (*_to_append.at(cur_idx)).into(), size: size - cur_idx * 16
                            }
                        );
                    break;
                }
            }
            _input
                .append(
                    ByteData {
                        value: (*_to_append.at(cur_idx)).into() ,size: 16
                    }
                );
            cur_idx +=1;
        };
        _input.span()
    }
}
