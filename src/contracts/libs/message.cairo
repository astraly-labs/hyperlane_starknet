use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
use core::keccak::keccak_u256s_be_inputs;
use core::poseidon::poseidon_hash_span;
use hyperlane_starknet::utils::keccak256::reverse_endianness;
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

    fn format_message(message: Message) -> u256 {
        let sender: felt252 = message.sender.into();
        let recipient: felt252 = message.recipient.into();

        let mut input: Array<u256> = array![
            message.version.into(),
            message.origin.into(),
            sender.into(),
            message.destination.into(),
            recipient.into(),
            message.body.size().into()
        ];
        let mut message_data = message.body.data();
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
