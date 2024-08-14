use alexandria_bytes::{Bytes, BytesTrait};


#[generate_trait]
pub impl TokenMessage of TokenMessageTrait {
    fn format(recipient: u256, amount: u256, metadata: Bytes) -> Bytes {
        let data: Array<u128> = array![recipient.low, recipient.high, amount.low, amount.high];
        let mut bytes = BytesTrait::new(4, data);
        bytes.concat(@metadata);
        bytes
    }

    fn recipient(self: @Bytes) -> u256 {
        let (_, recipient) = self.read_u256(0);
        recipient
    }

    fn amount(self: @Bytes) -> u256 {
        let (_, amount) = self.read_u256(32);
        amount
    }

    fn token_id(self: @Bytes) -> u256 {
        self.amount()
    }

    fn metadata(self: @Bytes) -> Bytes {
        let (_, bytes) = self.read_bytes(64, self.size() - 64);
        bytes
    }
}

