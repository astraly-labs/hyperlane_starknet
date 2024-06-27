use core::byte_array::{ByteArray, ByteArrayTrait};
use core::integer::u128_byte_reverse;
use core::keccak::cairo_keccak;
use core::to_byte_array::{FormatAsByteArray, AppendFormattedToByteArray};
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::HYPERLANE_ANNOUNCEMENT;
use starknet::{EthAddress, eth_signature::is_eth_signature_valid, secp256_trait::Signature};
use core::starknet::SyscallResultTrait;

pub const ETH_SIGNED_MESSAGE: felt252 = '\x19Ethereum Signed Message:\n32';


// TYPE DEFINITION
type Words64 = Span<u64>;

// CONSTANTS DEFINITION
const EMPTY_KECCAK: u256 = 0x70A4855D04D8FA7B3B2782CA53B600E5C003C7DCB27D7E923C23F7860146D2C5;
const ZERO_KECCAK: u256 = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;
pub const ONE_SHIFT_64: u128 = 0x10000000000000000;
pub const FELT252_MASK: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
pub const ADDRESS_SIZE: usize = 32;
pub const HASH_SIZE: usize = 32;
const KECCAK_FULL_RATE_IN_U64S: usize = 17;

/// 
/// Structure specifying for each element, the value of this element as u256 and the size (in bytes) of this element 
/// 
#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub struct ByteData {
    pub value: u256,
    pub size: usize
}


/// Reverses the endianness of an u256
/// 
/// # Arguments
/// 
/// * `value` - Value to reverse
/// 
/// # Returns 
/// 
/// the reverse equivalent 
pub fn reverse_endianness(value: u256) -> u256 {
    let new_low = u128_byte_reverse(value.high);
    let new_high = u128_byte_reverse(value.low);
    u256 { low: new_low, high: new_high }
}


/// Determines the Ethereum compatible signature for a given hash
/// dev : Since call this function for hash only, the ETH_SIGNED_MESSAGE size will always be 32
/// 
///  # Arguments
/// 
///  * `hash` - Hash to sign
/// 
/// # Returns the corresponding hash as big endian
pub fn to_eth_signature(hash: u256) -> u256 {
    let input = array![
        ByteData {
            value: ETH_SIGNED_MESSAGE.into(), size: u256_word_size(ETH_SIGNED_MESSAGE.into()).into()
        },
        ByteData { value: hash, size: HASH_SIZE }
    ];
    let hash = compute_keccak(input.span());
    reverse_endianness(hash)
}

/// Determines the correctness of an ethereum signature given a digest, signer and signature 
/// 
/// # Arguments 
/// 
/// * - `_msg_hash` - to digest used to sign the message
/// * - `_signature` - the signature to check
/// * - `_signer` - the signer ethereum address
/// 
/// # Returns 
/// 
/// boolean - True if valid
pub fn bool_is_eth_signature_valid(
    msg_hash: u256, signature: Signature, signer: EthAddress
) -> bool {
    match is_eth_signature_valid(msg_hash, signature, signer) {
        Result::Ok(()) => true,
        Result::Err(_) => false
    }
}



/// Determines the size of a u64 element, by successive division 
///
/// # Arguments
/// 
/// * `word` - u64 word to consider
/// 
/// # Returns
/// 
/// The size (in bytes) for the given word
pub fn u64_word_size(word: u64) -> u8 {
    let mut word_len = 0;
    while word_len < 8 {
        if word < one_shift_left_bytes_u64(word_len) {
            break;
        }
        word_len += 1;
    };
    word_len
}


/// Determines the size of a u256 element, by successive division 
///
/// # Arguments
/// 
/// * `word` - u256 word to consider
/// 
/// # Returns
/// 
/// The size (in bytes) for the given word
pub fn u256_word_size(word: u256) -> u8 {
    let mut word_len = 0;
    while word_len < 32 {
        if word < one_shift_left_bytes_u256(word_len) {
            break;
        }
        word_len += 1;
    };
    word_len
}



/// Shifts helper for u64
/// dev : panics if u64 overflow
/// 
/// # Arguments
/// 
/// * `n_bytes` - The number of bytes shift 
/// 
/// # Returns 
/// 
/// u64 representing the shifting number associated to the given number
pub fn one_shift_left_bytes_u64(n_bytes: u8) -> u64 {
    match n_bytes {
        0 => 0x1,
        1 => 0x100,
        2 => 0x10000,
        3 => 0x1000000,
        4 => 0x100000000,
        5 => 0x10000000000,
        6 => 0x1000000000000,
        7 => 0x100000000000000,
        _ => core::panic_with_felt252('n_bytes too big'),
    }
}



/// Shifts helper for u256
/// dev : panics if u256 overflow
/// 
/// # Arguments
/// 
/// * `n_bytes` - The number of bytes shift 
/// 
/// # Returns 
/// 
/// u256 representing the shifting number associated to the given number
pub fn one_shift_left_bytes_u256(n_bytes: u8) -> u256 {
    match n_bytes {
        0 => 0x1,
        1 => 0x100,
        2 => 0x10000,
        3 => 0x1000000,
        4 => 0x100000000,
        5 => 0x10000000000,
        6 => 0x1000000000000,
        7 => 0x100000000000000,
        8 => 0x10000000000000000,
        9 => 0x1000000000000000000,
        10 => 0x100000000000000000000,
        11 => 0x10000000000000000000000,
        12 => 0x1000000000000000000000000,
        13 => 0x100000000000000000000000000,
        14 => 0x10000000000000000000000000000,
        15 => 0x1000000000000000000000000000000,
        16 => 0x100000000000000000000000000000000,
        17 => 0x10000000000000000000000000000000000,
        18 => 0x1000000000000000000000000000000000000,
        19 => 0x100000000000000000000000000000000000000,
        20 => 0x10000000000000000000000000000000000000000,
        21 => 0x1000000000000000000000000000000000000000000,
        22 => 0x100000000000000000000000000000000000000000000,
        23 => 0x10000000000000000000000000000000000000000000000,
        24 => 0x1000000000000000000000000000000000000000000000000,
        25 => 0x100000000000000000000000000000000000000000000000000,
        26 => 0x10000000000000000000000000000000000000000000000000000,
        27 => 0x1000000000000000000000000000000000000000000000000000000,
        28 => 0x100000000000000000000000000000000000000000000000000000000,
        29 => 0x10000000000000000000000000000000000000000000000000000000000,
        30 => 0x1000000000000000000000000000000000000000000000000000000000000,
        31 => 0x100000000000000000000000000000000000000000000000000000000000000,
        _ => core::panic_with_felt252('n_bytes too big'),
    }
}


/// Givens a span of ByteData, returns a concatenated string (ByteArray) of the input
/// 
/// # Arguments
/// 
/// * `bytes` - a span of ByteData containing the information that need to be hash
/// 
/// # Returns 
/// 
/// ByteArray representing the concatenation of the input (bytes31). 
fn concatenate_input(bytes: Span<ByteData>) -> ByteArray {
    let mut output_string: ByteArray = Default::default();
    let mut cur_idx = 0;

    loop {
        if (cur_idx == bytes.len()) {
            break ();
        }
        let byte = *bytes.at(cur_idx);
        if (byte.size == 32) {
            // in order to store a 32-bytes entry in a ByteArray, we need to first append the upper 1-byte part , then the lower 31-bytes part
            let up_byte = (byte.value / FELT252_MASK).try_into().unwrap();
            output_string.append_word(up_byte, 1);
            let down_byte = (byte.value & FELT252_MASK).try_into().unwrap();
            output_string.append_word(down_byte, 31);
        } else {
            output_string.append_word(byte.value.try_into().unwrap(), byte.size);
        }
        cur_idx += 1;
    };
    output_string
}

pub fn compute_keccak_byte_array(arr: @ByteArray) -> u256 {
    let mut input = array![];
    let mut i = 0;
    let mut inner = 0;
    let mut limb: u64 = 0;
    let mut factor: u64 = 1;
    while let Option::Some(b) = arr.at(i) {
        limb = limb + b.into() * factor;
        i += 1;
        inner += 1;
        if inner == 8 {
            input.append(limb);
            inner = 0;
            limb = 0;
            factor = 1;
        } else {
            factor *= 0x100;
        }
    };
    add_padding(ref input, limb, inner);
    starknet::syscalls::keccak_syscall(input.span()).unwrap_syscall()
}


/// The padding in keccak256 is "1 0* 1".
/// `last_input_num_bytes` (0-7) is the number of bytes in the last u64 input - `last_input_word`.
fn add_padding(ref input: Array<u64>, last_input_word: u64, last_input_num_bytes: usize) {
    let words_divisor = KECCAK_FULL_RATE_IN_U64S.try_into().unwrap();
    // `last_block_num_full_words` is in range [0, KECCAK_FULL_RATE_IN_U64S - 1]
    let (_, last_block_num_full_words) = core::integer::u32_safe_divmod(input.len(), words_divisor);

    // The first word to append would be of the form
    //     0x1<`last_input_num_bytes` LSB bytes of `last_input_word`>.
    // For example, for `last_input_num_bytes == 4`:
    //     0x1000000 + (last_input_word & 0xffffff)
    let first_word_to_append = if last_input_num_bytes == 0 {
        // This case is handled separately to avoid unnecessary computations.
        1
    } else {
        let first_padding_byte_part = if last_input_num_bytes == 1 {
            0x100
        } else if last_input_num_bytes == 2 {
            0x10000
        } else if last_input_num_bytes == 3 {
            0x1000000
        } else if last_input_num_bytes == 4 {
            0x100000000
        } else if last_input_num_bytes == 5 {
            0x10000000000
        } else if last_input_num_bytes == 6 {
            0x1000000000000
        } else if last_input_num_bytes == 7 {
            0x100000000000000
        } else {
            core::panic_with_felt252('Keccak last input word >7b')
        };
        let (_, r) = core::integer::u64_safe_divmod(
            last_input_word, first_padding_byte_part.try_into().unwrap()
        );
        first_padding_byte_part + r
    };

    if last_block_num_full_words == KECCAK_FULL_RATE_IN_U64S - 1 {
        input.append(0x8000000000000000 + first_word_to_append);
        return;
    }

    // last_block_num_full_words < KECCAK_FULL_RATE_IN_U64S - 1
    input.append(first_word_to_append);
    finalize_padding(ref input, KECCAK_FULL_RATE_IN_U64S - 1 - last_block_num_full_words);
}

/// Finalize the padding by appending "0* 1".
fn finalize_padding(ref input: Array<u64>, num_padding_words: u32) {
    if (num_padding_words == 1) {
        input.append(0x8000000000000000);
        return;
    }

    input.append(0);
    finalize_padding(ref input, num_padding_words - 1);
}


/// The general function that computes the keccak hash for an input span of ByteData
/// 
/// # Arguments
/// 
/// * `bytes` - a span of ByteData containing the information for the hash computation
/// 
/// # Returns
/// 
/// The corresponding keccak hash for the input arguments
pub fn compute_keccak(bytes: Span<ByteData>) -> u256 {
    if (bytes.is_empty()) {
        return EMPTY_KECCAK;
    }
    if (*bytes.at(0).value == 0) {
        return ZERO_KECCAK;
    }
    let concatenate_input = concatenate_input(bytes);
    compute_keccak_byte_array(@concatenate_input)
}


#[cfg(test)]
mod tests {
    use alexandria_bytes::{Bytes, BytesTrait};
    use starknet::contract_address_const;
    use super::{
        reverse_endianness, ByteData, HYPERLANE_ANNOUNCEMENT, compute_keccak, u64_word_size,
        ADDRESS_SIZE
    };
    const TEST_STARKNET_DOMAIN: u32 = 23448594;


    #[test]
    fn test_reverse_endianness() {
        let big_endian_number: u256 = u256 { high: 0x12345678, low: 0 };
        let expected_result: u256 = u256 { high: 0, low: 0x78563412000000000000000000000000 };
        assert(
            reverse_endianness(big_endian_number) == expected_result, 'Failed to realise reverse'
        );
    }

    #[test]
    fn test_compute_keccak() {
        let array = array![ByteData { value: HYPERLANE_ANNOUNCEMENT.into(), size: 22 }];
        assert_eq!(
            compute_keccak(array.span()),
            0x4CE82A3F02824445F403FB5B69D4AB0FFFFC358BBAF61B0A130C971AB0CB15DA
        );

        let array = array![
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                size: ADDRESS_SIZE
            }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0x9D3185A7830200BD62EF9D26D44D9169A544C1FFA0FB98D0D56AAAA3BA8FE354
        );

        let array = array![ByteData { value: TEST_STARKNET_DOMAIN.into(), size: 4 }];
        assert_eq!(
            compute_keccak(array.span()),
            0xBC54A343AEF444F26F67F8538FE9F045A340D250AE50D019CB7528444FA32AEC
        );

        let array = array![
            ByteData { value: TEST_STARKNET_DOMAIN.into(), size: 4 },
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                size: ADDRESS_SIZE
            }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0x5DD6FF889DE1B20CF9B497A6716210C826DE3739FCAF50CD66F42F1DBE8626F2
        );

        let array = array![
            ByteData { value: TEST_STARKNET_DOMAIN.into(), size: 4 },
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                size: ADDRESS_SIZE
            },
            ByteData { value: HYPERLANE_ANNOUNCEMENT.into(), size: 22 }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0xFD8977CB20EE179678A5008D11A591D101FBDCC7669BC5CA31B92439A7E7FB4E
        );

        let array = array![
            ByteData {
                value: 0x61a4bcca63b5e8a46da3abe2080f75c16c18467d5838f00b375d9ba4c7c313dd,
                size: ADDRESS_SIZE
            },
            ByteData {
                value: 0x49d35915d0abec0a28990198bb32aa570e681e7eb41a001c0094c7c36a712671,
                size: ADDRESS_SIZE
            }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0x8310DAC21721349FCFA72BB5499303F0C6FAB4006FA2A637D02F7D6BB2188B47
        );
    }

    #[test]
    fn test_u64_word_size() {
        let test = 0x12345;
        assert_eq!(u64_word_size(test), 3);
        let test = 0x1234567890;
        assert_eq!(u64_word_size(test), 5);
        let test = 0xfffffffffffffff;
        assert_eq!(u64_word_size(test), 8);
        let test = 0xfff;
        assert_eq!(u64_word_size(test), 2);
        let test = 0x123456;
        assert_eq!(u64_word_size(test), 3);
        let test = 0x1;
        assert_eq!(u64_word_size(test), 1);
    }


}
