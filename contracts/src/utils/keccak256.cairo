use core::integer::u128_byte_reverse;
use core::keccak::cairo_keccak;
use core::keccak::{keccak_u256s_be_inputs, keccak_u256s_le_inputs};
use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{HYPERLANE_ANNOUNCEMENT};
pub const ETH_SIGNED_MESSAGE: felt252 = '\x19Ethereum Signed Message:\n32';


type Words64 = Span<u64>;
const EMPTY_KECCAK: u256 = 0x70A4855D04D8FA7B3B2782CA53B600E5C003C7DCB27D7E923C23F7860146D2C5;
pub const ONE_SHIFT_64: u128 = 0x10000000000000000;
pub const TEST_STARKNET_DOMAIN: u32 = 23448594;

#[derive(Copy, Drop)]
pub struct ByteData {
    pub value: u256,
    pub is_address: bool
}
/// Reverse the endianness of an u256
pub fn reverse_endianness(value: u256) -> u256 {
    let new_low = u128_byte_reverse(value.high);
    let new_high = u128_byte_reverse(value.low);
    u256 { low: new_low, high: new_high }
}


pub fn to_eth_signature(hash: u256) -> u256 {
    let input = array![
        ByteData { value: ETH_SIGNED_MESSAGE.into(), is_address: false },
        ByteData { value: hash, is_address: false }
    ];
    let hash = compute_keccak(input.span());
    reverse_endianness(hash)
}


pub fn u64_byte_reverse(value: u64) -> u64 {
    let reversed = u128_byte_reverse(value.into()) / ONE_SHIFT_64.try_into().expect('not zero');
    reversed.try_into().unwrap()
}


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
    if last_word_bytes == 8 {
        keccak_input.append(last);
        cairo_keccak(ref keccak_input, 0, 0)
    } else {
        cairo_keccak(ref keccak_input, last, last_word_bytes)
    }
}

// false if not full, true if full
pub fn bytes_size(bytes: ByteData) -> (u8, bool) {
    if (bytes.is_address) {
        return (32, true);
    }
    let mut n_bytes = 0;
    loop {
        if (n_bytes == 32) {
            break ();
        }
        if (one_shift_left_bytes_u256(n_bytes) > bytes.value) {
            break ();
        }
        n_bytes += 1;
    };
    if (n_bytes > 0) {
        (n_bytes, (bytes.value / one_shift_left_bytes_u256(n_bytes - 1)) > 0xf)
    } else {
        (n_bytes, true)
    }
}


pub fn get_filter(n_bytes: u8) -> u256 {
    0xFFFFFFFFFFFFFFFF * one_shift_left_bytes_u256(n_bytes)
}


pub fn u64_span_from_word(mut bytes_arr: Span<ByteData>) -> Span<u64> {
    let mut u64_arr: Array<u64> = array![];
    let (mut last_word, mut lw_nb_bytes, _): (u64, u8, bool) = (0, 0, false);
    loop {
        match bytes_arr.pop_front() {
            Option::Some(mut _byte) => {
                let (mut nb_bytes, is_full) = bytes_size(*_byte);
                let mut byte = *_byte.value;
                loop {
                    if (nb_bytes == 0) {
                        break ();
                    }
                    if (nb_bytes < 8 - lw_nb_bytes) {
                        last_word *=
                            if (lw_nb_bytes == 0) {
                                0
                            } else {
                                match is_full {
                                    true => one_shift_left_bytes_u256(nb_bytes).try_into().unwrap(),
                                    false => (one_shift_left_bytes_u256(nb_bytes) / 0x10)
                                        .try_into()
                                        .unwrap()
                                }
                            };
                        last_word += byte.try_into().unwrap();
                        lw_nb_bytes += nb_bytes;
                        break ();
                    } else if (nb_bytes == 8 - lw_nb_bytes) {
                        last_word *=
                            if (lw_nb_bytes == 0) {
                                0
                            } else {
                                match is_full {
                                    true => one_shift_left_bytes_u256(nb_bytes).try_into().unwrap(),
                                    false => (one_shift_left_bytes_u256(nb_bytes) / 0x10)
                                        .try_into()
                                        .unwrap()
                                }
                            };
                        last_word += byte.try_into().unwrap();
                        u64_arr.append(last_word);
                        last_word = 0;
                        lw_nb_bytes = 0;
                        break ();
                    } else {
                        let nb_diff = 8 - lw_nb_bytes;

                        let masked_byte = match is_full {
                            true => byte / one_shift_left_bytes_u256(nb_bytes - nb_diff).into(),
                            false => byte
                                / (one_shift_left_bytes_u256(nb_bytes - nb_diff) / 0x10).into()
                        };
                        last_word *=
                            if (lw_nb_bytes == 0) {
                                0
                            } else {
                                one_shift_left_bytes_u256(nb_diff).try_into().unwrap()
                            };

                        last_word += masked_byte.try_into().unwrap();
                        u64_arr.append(last_word);
                        byte = match is_full {
                            true => byte % one_shift_left_bytes_u256(nb_bytes - nb_diff).into(),
                            false => byte % (one_shift_left_bytes_u256(nb_bytes - nb_diff) / 0x10)
                                .into()
                        };

                        last_word = 0;
                        lw_nb_bytes = 0;
                        nb_bytes -= nb_diff;
                    }
                };
            },
            Option::None(_) => {
                if (last_word != 0) {
                    u64_arr.append(last_word);
                }
                break ();
            }
        }
    };
    u64_arr.span()
}

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

fn reverse_u64_word(bytes: Span<u64>) -> Span<u64> {
    let mut cur_idx = 0;
    let mut reverse_u64 = array![];
    let last_word = *bytes.at(bytes.len() - 1);
    let (n_bytes, is_full) = bytes_size(ByteData { value: last_word.into(), is_address: false });
    loop {
        if (cur_idx == bytes.len()) {
            break ();
        }
        if (cur_idx == bytes.len() - 1) {
            reverse_u64
                .append(
                    u64_byte_reverse(*bytes.at(cur_idx))
                        / one_shift_left_bytes_u256(8 - n_bytes).try_into().unwrap()
                );
        } else {
            reverse_u64.append(u64_byte_reverse(*bytes.at(cur_idx)));
        }
        cur_idx += 1;
    };
    reverse_u64.span()
}


pub fn compute_keccak(bytes: Span<ByteData>) -> u256 {
    let words64 = u64_span_from_word(bytes);

    let last_word = *words64.at(words64.len() - 1);
    let reverse_words64 = reverse_u64_word(words64);

    let (n_bytes, _) = bytes_size(ByteData { value: last_word.into(), is_address: false });
    keccak_cairo_words64(reverse_words64, n_bytes.into())
}


#[cfg(test)]
mod tests {
    use super::{
        reverse_endianness, ByteData, HYPERLANE_ANNOUNCEMENT, compute_keccak, TEST_STARKNET_DOMAIN,
        bytes_size, u64_span_from_word, reverse_u64_word
    };
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
        let array = array![ByteData { value: HYPERLANE_ANNOUNCEMENT.into(), is_address: false }];
        assert_eq!(
            compute_keccak(array.span()),
            0x4CE82A3F02824445F403FB5B69D4AB0FFFFC358BBAF61B0A130C971AB0CB15DA
        );

        let array = array![
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                is_address: true
            }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0x9D3185A7830200BD62EF9D26D44D9169A544C1FFA0FB98D0D56AAAA3BA8FE354
        );

        let array = array![ByteData { value: TEST_STARKNET_DOMAIN.into(), is_address: false }];
        assert_eq!(
            compute_keccak(array.span()),
            0xBC54A343AEF444F26F67F8538FE9F045A340D250AE50D019CB7528444FA32AEC
        );

        let array = array![
            ByteData { value: TEST_STARKNET_DOMAIN.into(), is_address: false },
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                is_address: true
            }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0x5DD6FF889DE1B20CF9B497A6716210C826DE3739FCAF50CD66F42F1DBE8626F2
        );

        let array = array![
            ByteData { value: TEST_STARKNET_DOMAIN.into(), is_address: false },
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                is_address: true
            },
            ByteData { value: HYPERLANE_ANNOUNCEMENT.into(), is_address: false }
        ];
        assert_eq!(
            compute_keccak(array.span()),
            0xFD8977CB20EE179678A5008D11A591D101FBDCC7669BC5CA31B92439A7E7FB4E
        );
    }

    #[test]
    fn test_bytes_size() {
        let test = ByteData { value: 0x12345, is_address: false };
        assert_eq!(bytes_size(test), (3, false));
        let test = ByteData { value: 0x1234567890, is_address: false };
        assert_eq!(bytes_size(test), (5, true));
        let test = ByteData { value: 0xfffffffffffffffffff, is_address: false };
        assert_eq!(bytes_size(test), (10, false));
        let test = ByteData { value: 0xfff, is_address: false };
        assert_eq!(bytes_size(test), (2, false));
        let test = ByteData { value: 0x123456, is_address: false };
        assert_eq!(bytes_size(test), (3, true));
        let test = ByteData { value: 0x1, is_address: false };
        assert_eq!(bytes_size(test), (1, false));
        let test = ByteData {
            value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
            is_address: true
        };
        assert_eq!(bytes_size(test), (32, true));
    }


    #[test]
    fn test_u64_from_input() {
        let input = array![
            ByteData { value: 0x4, is_address: false },
            ByteData { value: 0x5, is_address: false },
            ByteData { value: 0x6, is_address: false }
        ]
            .span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![0x456].span();
        assert_eq!(span_input, expected_result);

        let input = array![
            ByteData { value: 0x40, is_address: false },
            ByteData { value: 0x50, is_address: false },
            ByteData { value: 0x60, is_address: false }
        ]
            .span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![0x405060].span();
        assert_eq!(span_input, expected_result);

        let input = array![
            ByteData { value: 0x4000, is_address: false },
            ByteData { value: 0x5000, is_address: false },
            ByteData { value: 0x6000, is_address: false },
            ByteData { value: 0x7000, is_address: false }
        ]
            .span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![0x4000500060007000].span();
        assert_eq!(span_input, expected_result);

        let input = array![ByteData { value: 0x48595045524c414e45, is_address: false }].span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![0x48595045524c414e, 0x45].span();
        assert_eq!(span_input, expected_result);

        let input = array![ByteData { value: 0x48595045524c414e457, is_address: false }].span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![0x48595045524c414e, 0x457].span();
        assert_eq!(span_input, expected_result);

        let input = array![
            ByteData {
                value: 0x007a9a2e1663480b3845df0d714e8caa49f9241e13a826a678da3f366e546f2a,
                is_address: true
            }
        ]
            .span();
        let span_input = u64_span_from_word(input);
        let expected_result = array![
            0x007a9a2e1663480b, 0x3845df0d714e8caa, 0x49f9241e13a826a6, 0x78da3f366e546f2a
        ]
            .span();
        assert_eq!(span_input, expected_result);
        let input_2 = array![
            ByteData { value: 0x48595045524c414e45, is_address: false },
            ByteData { value: 0x12343153153132342343, is_address: false },
            ByteData { value: 0x1231312321312333333, is_address: false }
        ]
            .span();
        let span_input_2 = u64_span_from_word(input_2);
        let expected_result_2 = array![
            0x48595045524c414e, 0x4512343153153132, 0x3423431231312321, 0x312333333
        ]
            .span();
        assert_eq!(span_input_2, expected_result_2);
        let input_2 = array![
            ByteData { value: 0x12CC6501, is_address: false },
            ByteData { value: 0x12343153153132342343, is_address: false },
            ByteData { value: 0x1231312321312333333, is_address: false }
        ]
            .span();
        let span_input_2 = u64_span_from_word(input_2);
        let expected_result_2 = array![0x12CC650112343153, 0x1531323423431231, 0x312321312333333]
            .span();
        assert_eq!(span_input_2, expected_result_2);
    }

    #[test]
    fn test_reverse_u64_word() {
        let array = array![0x12345656, 0x46e12df86, 0x23e098a8c5b850];
        let expected_result = array![0x5656341200000000, 0x86df126e04000000, 0x50b8c5a898e023];
        assert_eq!(reverse_u64_word(array.span()), expected_result.span());

        let array = array![0x12345656, 0x46e12df86, 0x23e098a8c5b85040];
        let expected_result = array![0x5656341200000000, 0x86df126e04000000, 0x4050b8c5a898e023];
        assert_eq!(reverse_u64_word(array.span()), expected_result.span());

        let array = array![
            0x007a9a2e1663480b, 0x3845df0d714e8caa, 0x49f9241e13a826a6, 0x78da3f366e546f2a
        ];
        let expected_result = array![
            0x0B4863162E9A7A00, 0xAA8C4E710DDF4538, 0xA626A8131E24F949, 0x2A6F546E363FDA78
        ];
        assert_eq!(reverse_u64_word(array.span()), expected_result.span());

        let array = array![0x0165CC12];
        let expected_result = array![0x12cc6501];
        assert_eq!(reverse_u64_word(array.span()), expected_result.span());
    }
}
