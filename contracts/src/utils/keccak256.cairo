use core::byte_array::{ByteArray, ByteArrayTrait};
use core::integer::u128_byte_reverse;
use core::keccak::cairo_keccak;
use core::to_byte_array::{FormatAsByteArray, AppendFormattedToByteArray};
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::HYPERLANE_ANNOUNCEMENT;
use starknet::{EthAddress, eth_signature::is_eth_signature_valid, secp256_trait::Signature};

pub const ETH_SIGNED_MESSAGE: felt252 = '\x19Ethereum Signed Message:\n32';


// TYPE DEFINITION
type Words64 = Span<u64>;

// CONSTANTS DEFINITION
const EMPTY_KECCAK: u256 = 0x70A4855D04D8FA7B3B2782CA53B600E5C003C7DCB27D7E923C23F7860146D2C5;
pub const ONE_SHIFT_64: u128 = 0x10000000000000000;
pub const FELT252_MASK: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
pub const ADDRESS_SIZE: usize = 32;
pub const HASH_SIZE: usize = 32;


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

/// Reverses an u64 word (little_endian <-> big endian)
/// For example 0x12345678 will return 0x78563412
/// For this function, we used an existing function of the cairo lib `u128_byte_reverse`
/// 
/// # Argument 
/// 
///  * - `value` - value to reverse 
/// 
/// # Returns 
/// 
/// The equivalent little endian (or big endian)
pub fn u64_byte_reverse(value: u64) -> u64 {
    let reversed = u128_byte_reverse(value.into()) / ONE_SHIFT_64.try_into().expect('not zero');
    reversed.try_into().unwrap()
}


/// Computes the keccak hash of an given input of Words64(Span<u64>)
/// dev: harcoded result if the array is empty
/// dev: using keccak hash function (`cairo_keccak`) from the cairo core lib
///  
/// # Arguments
/// 
/// * `words` - A Words64 element containing the information to be hash, as u64 span.
/// * `last_word_bytes` - the size(in bytes) of the last word in the words span. 
/// 
/// # Returns the corresponding hash
fn keccak_cairo_words64(words: Words64, last_word_bytes: usize) -> u256 {
    if words.is_empty() {
        return EMPTY_KECCAK;
    }

    let n = words.len();
    let mut keccak_input = ArrayTrait::new();
    let mut i: usize = 0;
    loop {
        if i >= n - 1 {
            break ();
        }
        keccak_input.append(*words.at(i));
        i += 1;
    };

    let mut last = *words.at(n - 1);
    if (last_word_bytes == 8 || last_word_bytes == 0) {
        keccak_input.append(last);
        cairo_keccak(ref keccak_input, 0, 0)
    } else {
        cairo_keccak(ref keccak_input, last, last_word_bytes)
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

/// Builds an u64 span out of a concatenated string (ByteArray)
/// dev: ByteArray is in fact a array of Bytes31 (u8) 
/// 
/// # Argument
/// 
/// * `bytes` - A string containing the concatenation of all the arguments to hash
/// 
/// # Returns 
/// 
/// A span of u64 associated to the input
fn build_u64_array(bytes: @ByteArray) -> Span<u64> {
    let mut u64_array = array![];
    let mut cur_idx = 0;
    let bytes_len = bytes.len();
    loop {
        // Break the loop if we've processed all the bytes
        if cur_idx * 8 >= bytes_len {
            break;
        }
        let mut u64_word: u64 = 0;
        let mut offset: u8 = 0;
        let remaining_bytes = bytes_len - cur_idx * 8;
        loop {
            if offset == 8 || cur_idx * 8 + offset.into() >= bytes_len {
                break;
            }
            let u8_bytes: u8 = bytes[cur_idx * 8 + offset.into()];
            let shift: u8 = if (remaining_bytes < 8) {
                remaining_bytes.try_into().unwrap()
            } else {
                8
            };
            u64_word += u8_bytes.into() * one_shift_left_bytes_u64(shift - 1 - offset);
            offset += 1;
        };
        u64_array.append(u64_word);
        cur_idx += 1;
    };
    u64_array.span()
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

/// Retrieves the two last words (u64) for a given string (ByteArray)
/// 
/// # Arguments
/// * `word` - a snapshot of the string to consider 
/// * `last_word_len` - the length of the last word
/// 
/// # Returns 
/// 
/// The last two words as u128. 
fn get_two_last_words(word: @ByteArray, last_word_len: u8) -> u128 {
    let mut u128_res: u128 = 0;
    let stop_index: usize = word.len();
    let start_index = stop_index - last_word_len.into() - 8;
    let mid_index = start_index + 8;
    let mut i = start_index;
    while i < mid_index
        && i < stop_index {
            let byte: u128 = word[i].into();
            let pos: u8 = (i - start_index).try_into().unwrap();
            u128_res += byte
                * one_shift_left_bytes_u256(8 + last_word_len - 1 - pos).try_into().unwrap();
            i += 1;
        };
    while i < stop_index {
        let byte: u128 = word[i].into();
        let pos: u8 = (i - mid_index).try_into().unwrap();
        u128_res += byte * one_shift_left_bytes_u64(last_word_len - 1 - pos).try_into().unwrap();
        i += 1;
    };
    u128_res
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


pub fn u128_mask(n_bytes: u8) -> u128 {
    match n_bytes {
        0 => 0,
        1 => 0xFF,
        2 => 0xFFFF,
        3 => 0xFFFFFF,
        4 => 0xFFFFFFFF,
        5 => 0xFFFFFFFFFF,
        6 => 0xFFFFFFFFFFFF,
        7 => 0xFFFFFFFFFFFFFF,
        8 => 0xFFFFFFFFFFFFFFFF,
        9 => 0xFFFFFFFFFFFFFFFFFF,
        10 => 0xFFFFFFFFFFFFFFFFFFFF,
        11 => 0xFFFFFFFFFFFFFFFFFFFFFF,
        12 => 0xFFFFFFFFFFFFFFFFFFFFFFFF,
        13 => 0xFFFFFFFFFFFFFFFFFFFFFFFFFF,
        14 => 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        15 => 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        16 => 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        _ => core::panic_with_felt252('n_bytes too big'),
    }
}


/// Reverses an u64 word. If a padding is provided, shift the result with the padding. 
/// 
/// # Arguments
/// 
/// * `words` - Span of u64, which is the concatenation of the arguments put into u64s
/// * `padding` - Padding, to avoid information loss (see https://github.com/astraly-labs/hyperlane_starknet/pull/39)
/// 
/// # Returns 
/// 
/// A span of u64 corresponding to the reverse endianness of the input. 
fn reverse_u64_word(words: Span<u64>, padding: u8) -> Span<u64> {
    let mut cur_idx = 0;
    let mut reverse_u64 = array![];
    let last_word = *words.at(words.len() - 1);
    let number_words = u64_word_size(last_word);
    loop {
        if (cur_idx == words.len()) {
            break ();
        }
        if (cur_idx == words.len() - 1) {
            if (number_words == 0) {
                reverse_u64.append(0_u64);
            } else {
                reverse_u64
                    .append(
                        (u64_byte_reverse(*words.at(cur_idx))
                            / one_shift_left_bytes_u64(8 - number_words))
                            * one_shift_left_bytes_u64(padding)
                    );
            }
        } else {
            reverse_u64.append(u64_byte_reverse(*words.at(cur_idx)));
        }
        cur_idx += 1;
    };
    reverse_u64.span()
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
        return keccak_cairo_words64(array![].span(), 0);
    }
    if (*bytes.at(0).value == 0) {
        return keccak_cairo_words64(array![].span(), 0);
    }
    let concatenate_input = concatenate_input(bytes);
    let size = concatenate_input.len();

    let u64_span = build_u64_array(@concatenate_input);
    let mut padding = 0;
    // if there two words at lest, we need to make sure that the u64 span separation does not remove information on the last word
    if size > 8 {
        let size_last_word = if (size % 8 != 0) {
            size % 8
        } else {
            8
        };
        let two_last_word = get_two_last_words(
            @concatenate_input, size_last_word.try_into().unwrap()
        );
        let u128_last_word: u128 = (*u64_span.at(u64_span.len() - 1)).into();
        let size_concat_words = u256_word_size(two_last_word.into());
        let size_arr_word = u256_word_size(u128_last_word.into());
        padding =
            if (size_concat_words == 0 && size_arr_word == 0) {
                0
            } else if (size_arr_word + 8 != size_concat_words) {
                size_concat_words - (size_arr_word + 8)
            } else {
                0
            };
    }
    let reverse_words64 = reverse_u64_word(u64_span, padding);
    let n_bytes = u64_word_size(*reverse_words64.at(reverse_words64.len() - 1));
    keccak_cairo_words64(reverse_words64, n_bytes.into())
}


#[cfg(test)]
mod tests {
    use alexandria_bytes::{Bytes, BytesTrait};
    use starknet::contract_address_const;
    use super::{
        reverse_endianness, ByteData, HYPERLANE_ANNOUNCEMENT, compute_keccak, u64_word_size,
        reverse_u64_word, cairo_keccak, keccak_cairo_words64, build_u64_array, get_two_last_words,
        ADDRESS_SIZE
    };
    const TEST_STARKNET_DOMAIN: u32 = 23448594;


    #[test]
    fn test_get_last_two_words() {
        let mut input = Default::default();
        input.append_word(0x49, 1);
        input.append_word(0xd35915d0abec0a28990198bb32aa570e681e7eb41a001c0094c7c36a712671, 31);
        let expected_result = 0x0e681e7eb41a001c0094c7c36a712671;
        assert_eq!(get_two_last_words(@input, 8), expected_result);
        let mut input = Default::default();
        input.append_word('HYPERLANE_ANNOUNCEMENT', 22);
        let expected_result = 'E_ANNOUNCEMENT';
        assert_eq!(get_two_last_words(@input, 6), expected_result);
    }
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


    #[test]
    fn test_u64_from_input() {
        let mut input = Default::default();
        input.append_word(0x40, 1);
        input.append_word(0x50, 1);
        input.append_word(0x60, 1);

        let span_input = build_u64_array(@input);
        let expected_result = array![0x405060].span();
        assert_eq!(span_input, expected_result);

        let mut input = Default::default();
        input.append_word(0x4000, 2);
        input.append_word(0x5000, 2);
        input.append_word(0x6000, 2);
        input.append_word(0x7000, 2);

        let span_input = build_u64_array(@input);
        let expected_result = array![0x4000500060007000].span();
        assert_eq!(span_input, expected_result);

        let mut input = Default::default();
        input.append_word(0x48595045524c414e45, 9);
        let span_input = build_u64_array(@input);
        let expected_result = array![0x48595045524c414e, 0x45].span();
        assert_eq!(span_input, expected_result);

        let mut input = Default::default();
        input.append_word(0x48595045524c414e457, 10);
        let span_input = build_u64_array(@input);
        let expected_result = array![0x48595045524c414, 0xe457].span();
        assert_eq!(span_input, expected_result);

        let mut input = Default::default();
        input.append_word(0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a, 32);
        let span_input = build_u64_array(@input);
        let expected_result = array![
            0x007a9a2e1663480b, 0x3845df0d714e8caa, 0x49f9241e13a826a6, 0x78da3f366e546f2a
        ]
            .span();
        assert_eq!(span_input, expected_result);

        let mut input = Default::default();
        input.append_word(0x48595045524c414e45, 9);
        input.append_word(0x12343153153132342343, 10);
        input.append_word(0x1231312321312333333, 10);
        let span_input_2 = build_u64_array(@input);
        let expected_result_2 = array![
            0x48595045524c414e, 0x4512343153153132, 0x3423430123131232, 0x1312333333
        ]
            .span();
        assert_eq!(span_input_2, expected_result_2);

        let mut input = Default::default();
        input.append_word(0x12CC6501, 4);
        input.append_word(0x12343153153132342343, 10);
        input.append_word(0x1231312321312333333, 10);

        let span_input_2 = build_u64_array(@input);
        let expected_result_2 = array![0x12CC650112343153, 0x1531323423430123, 0x1312321312333333]
            .span();
        assert_eq!(span_input_2, expected_result_2);

        let mut input = Default::default();
        input.append_word(0x61, 1);
        input.append_word(0xa4bcca63b5e8a46da3abe2080f75c16c18467d5838f00b375d9ba4c7c313dd, 31);
        let span_input_2 = build_u64_array(@input);
        let expected_result_2 = array![
            0x61a4bcca63b5e8a4, 0x6da3abe2080f75c1, 0x6c18467d5838f00b, 0x375d9ba4c7c313dd
        ]
            .span();
        assert_eq!(span_input_2, expected_result_2);

        let mut input = Default::default();
        input.append_word(0x49, 1);
        input.append_word(0xd35915d0abec0a28990198bb32aa570e681e7eb41a001c0094c7c36a712671, 31);
        let span_input_2 = build_u64_array(@input);
        let expected_result_2 = array![
            0x49d35915d0abec0a, 0x28990198bb32aa57, 0x0e681e7eb41a001c, 0x0094c7c36a712671
        ]
            .span();
        assert_eq!(span_input_2, expected_result_2);

        let mut input = Default::default();
        input.append_word(0x61, 1);
        input.append_word(0xa4bcca63b5e8a46da3abe2080f75c16c18467d5838f00b375d9ba4c7c313dd, 31);
        input.append_word(0x49, 1);
        input.append_word(0xd35915d0abec0a28990198bb32aa570e681e7eb41a001c0094c7c36a712671, 31);
        let span_input_2 = build_u64_array(@input);
        let expected_result_2 = array![
            0x61a4bcca63b5e8a4,
            0x6da3abe2080f75c1,
            0x6c18467d5838f00b,
            0x375d9ba4c7c313dd,
            0x49d35915d0abec0a,
            0x28990198bb32aa57,
            0x0e681e7eb41a001c,
            0x0094c7c36a712671
        ]
            .span();
        assert_eq!(span_input_2, expected_result_2);
    }

    #[test]
    fn test_reverse_u64_word() {
        let array = array![0x12345656, 0x46e12df86, 0x23e098a8c5b850];
        let expected_result = array![0x5656341200000000, 0x86df126e04000000, 0x50b8c5a898e023];
        assert_eq!(reverse_u64_word(array.span(), 0), expected_result.span());

        let array = array![0x12345656, 0x46e12df86, 0x23e098a8c5b85040];
        let expected_result = array![0x5656341200000000, 0x86df126e04000000, 0x4050b8c5a898e023];
        assert_eq!(reverse_u64_word(array.span(), 0), expected_result.span());

        let array = array![
            0x007a9a2e1663480b, 0x3845df0d714e8caa, 0x49f9241e13a826a6, 0x78da3f366e546f2a
        ];
        let expected_result = array![
            0x0B4863162E9A7A00, 0xAA8C4E710DDF4538, 0xA626A8131E24F949, 0x2A6F546E363FDA78
        ];
        assert_eq!(reverse_u64_word(array.span(), 0), expected_result.span());

        let array = array![0x0165CC12];
        let expected_result = array![0x12cc6501];
        assert_eq!(reverse_u64_word(array.span(), 0), expected_result.span());

        let array = array![
            0x61a4bcca63b5e8a4,
            0x6da3abe2080f75c1,
            0x6c18467d5838f00b,
            0x375d9ba4c7c313dd,
            0x49d35915d0abec0a,
            0x28990198bb32aa57,
            0x0e681e7eb41a001c,
            0x0094c7c36a712671
        ];
        let expected_result = array![
            0xa4e8b563cabca461,
            0xc1750f08e2aba36d,
            0x0bf038587d46186c,
            0xdd13c3c7a49b5d37,
            0x0aecabd01559d349,
            0x57aa32bb98019928,
            0x1c001ab47e1e680e,
            0x7126716ac3c79400
        ];
        assert_eq!(reverse_u64_word(array.span(), 1), expected_result.span());
    }
}
