use crate::libs::message::Message;
use starknet::ContractAddress;
use alexandria_bytes::Bytes;
use core::serde::Serde;

pub impl U256TryIntoContractAddress of TryInto<u256, ContractAddress> {
    fn try_into(self: u256) -> Option<ContractAddress> {
        let maybe_value: Option<felt252> = self.try_into();
        match maybe_value {
            Option::Some(value) => value.try_into(),
            Option::None => Option::None,
        }
    }
}



pub impl SerdeSnapshotBytes of Serde<@Bytes> {
    fn serialize(self: @@Bytes, ref output: Array<felt252>) {
        Serde::<Bytes>::serialize(*self, ref output)
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<@Bytes> {
        Option::Some(@Serde::<Bytes>::deserialize(ref serialized)?)
    }
}

pub impl SerdeSnapshotMessage of Serde<@Message> {
    fn serialize(self: @@Message, ref output: Array<felt252>) {
        Serde::<Message>::serialize(*self, ref output)
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<@Message> {
        Option::Some(@Serde::<Message>::deserialize(ref serialized)?)
    }
}

