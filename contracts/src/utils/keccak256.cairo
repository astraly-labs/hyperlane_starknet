use core::integer::u128_byte_reverse;
use core::keccak::{keccak_u256s_be_inputs, keccak_u256s_le_inputs};
pub const ETH_SIGNED_MESSAGE: felt252 = '\x19Ethereum Signed Message:\n34';

/// Reverse the endianness of an u256
pub fn reverse_endianness(value: u256) -> u256 {
    let new_low = u128_byte_reverse(value.high);
    let new_high = u128_byte_reverse(value.low);
    u256 { low: new_low, high: new_high }
}


pub fn to_eth_signature(hash: u256) -> u256 {
    let input = array![ETH_SIGNED_MESSAGE.into(), hash];
    let hash = keccak_u256s_be_inputs(input.span());
    // reverse_endianness(hash)
    hash
}

#[cfg(test)]
mod tests {
    use super::{reverse_endianness, to_eth_signature};
    #[test]
    fn test_reverse_endianness() {
        let big_endian_number: u256 = u256 { high: 0x12345678, low: 0 };
        let expected_result: u256 = u256 { high: 0, low: 0x78563412000000000000000000000000 };
        assert(
            reverse_endianness(big_endian_number) == expected_result, 'Failed to realise reverse'
        );
    }

    #[test]
    fn test_eth_signed_message() {
        let message = 0x10101010101010101010101010101010_u256;
        let expected_message_hash =
            0xd9eba16ed0ecae432b71fe008c98cc872bb4cc214d3220a36f365326cf807d68_u256;
        assert_eq!(to_eth_signature(message), expected_message_hash);
    }
}
