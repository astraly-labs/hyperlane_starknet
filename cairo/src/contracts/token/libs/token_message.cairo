pub mod TokenMessage {
    pub fn format(recipient: felt252, amount: u256, metadata: u256) -> u256 {
        0
    }

    pub fn recipient(message: felt252) -> u256 {
        0
    }

    pub fn amount(message: felt252) -> u256 {
        0
    }

    pub fn token_id(message: felt252) -> u256 {
        amount(message)
    }

    pub fn metadata(message: felt252) -> u256 {
        0
    }
}

