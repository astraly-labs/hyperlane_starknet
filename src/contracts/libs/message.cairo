use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use core::poseidon::poseidon_hash_span;

use starknet::{ContractAddress, contract_address_const};


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

    fn id(self: Message) -> felt252 {
        let message_array: Array<felt252> = array![
            self.version.into(),
            self.nonce.into(),
            self.origin.into(),
            self.sender.into(),
            self.destination.into(),
            self.recipient.into()
        ];
        poseidon_hash_span(message_array.span())
    }

    fn format_message(_version: u8, _nonce: u32, _origin_domain: u32, _sender: ContractAddress, _destination_domain: u32, _recipient: ContractAddress, _message_body: Bytes)-> u256{
        // POSEIDON MAY BE BETTER HERE
        let mut bytes: Bytes = BytesTrait::new(0, array![]);
        bytes.append_u8(_version);
        bytes.append_u32(_nonce);
        bytes.append_u32(_origin_domain);
        bytes.append_address(_sender);
        bytes.append_u32(_destination_domain);
        bytes.append_address(_recipient);
        // bytes.append_bytes31(_message_body);
        let keccak_hash = bytes.keccak();
        keccak_hash
        }
}
