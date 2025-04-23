use alexandria_bytes::bytes::{Bytes, BytesTrait};
use core::array::ArrayTrait;
use core::serde::{Serde, SerdeTrait};

impl SerdeBytes of Serde<Bytes> {
    fn serialize(self: @Bytes, ref output: Array<felt252>) {
        // Serialize length first
        Serde::<usize>::serialize(@self.len(), ref output);

        // Serialize data
        let mut i: usize = 0;
        while i < self.len() {
            Serde::<u8>::serialize(@self.at(i), ref output);
            i += 1;
        }
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<Bytes> {
        // Deserialize length
        let len = Serde::<usize>::deserialize(ref serialized)?;

        // Create bytes and append each byte
        let mut bytes = BytesTrait::new_empty();
        let mut i: usize = 0;
        while i < len {
            let byte = Serde::<u8>::deserialize(ref serialized)?;
            bytes.append_byte(byte);
            i += 1;
        }

        Option::Some(bytes)
    }
}

// Also implement for snapshots which are used in interfaces
impl SerdeSnapshotBytes of Serde<@Bytes> {
    fn serialize(self: @@Bytes, ref output: Array<felt252>) {
        Serde::<Bytes>::serialize(@self, ref output)
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<@Bytes> {
        Option::Some(@Serde::<Bytes>::deserialize(ref serialized)?)
    }
}
