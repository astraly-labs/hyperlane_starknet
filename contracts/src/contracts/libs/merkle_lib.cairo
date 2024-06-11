pub mod merkle_lib {
    use alexandria_math::pow;
    use core::keccak::keccak_u256s_be_inputs;
    use hyperlane_starknet::utils::keccak256::reverse_endianness;
    pub const TREE_DEPTH: u32 = 32;


    #[derive(Serde, Drop)]
    pub struct Tree {
        pub branch: Array<u256>,
        pub count: u256
    }

    pub mod Errors {
        pub const MERKLE_TREE_FULL: felt252 = 'Merkle tree full';
    }

    #[generate_trait]
    pub impl MerkleLibImpl of MerkleLib {
        fn new() -> Tree {
            let mut array = array![];
            let mut i: u32 = 0;
            loop {
                if (i == TREE_DEPTH) {
                    break ();
                }
                array.append(0_u256);
                i += 1;
            };
            Tree { branch: array, count: 0_u256 }
        }
        fn insert(ref self: Tree, mut _node: u256) {
            let MAX_LEAVES: u128 = pow(2_u128, TREE_DEPTH.into()) - 1;
            assert(self.count < MAX_LEAVES.into(), Errors::MERKLE_TREE_FULL);
            self.count += 1;
            let mut size = self.count;
            let mut cur_idx = 0;
            loop {
                if (cur_idx == TREE_DEPTH) {
                    break ();
                }
                if ((size & 1) == 1) {
                    insert_into_array(ref self, _node, cur_idx);
                    break ();
                }
                _node = keccak_u256s_be_inputs(array![*self.branch.at(cur_idx), _node].span());
                size /= 2;
                cur_idx += 1;
            };
            println!("function is finished");
        }

        fn root_with_ctx(self: @Tree, _zeroes: Array<u256>) -> u256 {
            let mut cur_idx = 0;
            let index = *self.count;
            let mut current = *_zeroes[0]; // TO BE VERIFIED
            loop {
                if (cur_idx == TREE_DEPTH) {
                    break ();
                }
                let ith_bit = get_ith_bit(index, cur_idx);
                let next = *self.branch.at(cur_idx);
                if (ith_bit == 1) {
                    current = keccak_u256s_be_inputs(array![next, current].span());
                } else {
                    current = keccak_u256s_be_inputs(array![current, *_zeroes.at(cur_idx)].span());
                }
                cur_idx += 1;
            };
            current
        }

        fn branch_root(_item: u256, _branch: Span<u256>, _index: u256) -> u256 {
            let mut cur_idx = 0;
            let mut current = _item;
            loop {
                if (cur_idx == TREE_DEPTH) {
                    break ();
                }
                let ith_bit = get_ith_bit(_index, cur_idx);
                let next = *_branch.at(cur_idx);
                if (ith_bit == 1) {
                    current = keccak_u256s_be_inputs(array![next, current].span());
                } else {
                    current = keccak_u256s_be_inputs(array![current, next].span());
                }
                cur_idx += 1;
            };
            current
        }

        fn root(self: @Tree) -> u256 {
            self.root_with_ctx(zero_hashes())
        }
    }


    fn insert_into_array(ref self: Tree, _node: u256, _index: u32) {
        let mut array = array![];
        let mut cur_idx = 0;
        loop {
            if (cur_idx == self.branch.len()) {
                break ();
            }
            if (cur_idx == _index) {
                array.append(_node);
            } else {
                array.append(*self.branch.at(cur_idx))
            }
            cur_idx += 1;
        };
        self.branch = array;
    }

    fn get_ith_bit(_index: u256, i: u32) -> u256 {
        let mask = pow(2.into(), i.into());
        _index & mask / mask
    }

    pub fn zero_hashes() -> Array<u256> {
        array![
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5,
            0xb4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d30,
            0x21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85,
            0xe58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a19344,
            0x0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d,
            0x887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968,
            0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83,
            0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af,
            0xcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0,
            0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5,
            0xf8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892,
            0x3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c,
            0xc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb,
            0x5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc,
            0xda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2,
            0x2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f,
            0xe1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a,
            0x5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0,
            0xb46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0,
            0xc65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2,
            0xf4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9,
            0x5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377,
            0x4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652,
            0xcdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef,
            0x0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d,
            0xb8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0,
            0x838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34,
        ]
    }
}


#[cfg(test)]
mod tests {
    use alexandria_math::pow;
    use core::keccak::keccak_u256s_be_inputs;
    use super::merkle_lib::{MerkleLib, Tree, zero_hashes, TREE_DEPTH};

    #[test]
    fn test_insert_and_root() {
        let mut tree = MerkleLib::new();

        // Insert a single leaf
        let leaf = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef_u256;
        tree.insert(leaf);

        // Compute root with context
        let zero_hashes = zero_hashes();
        let root_with_ctx = tree.root_with_ctx(zero_hashes.clone());

        // Compute root
        let root = tree.root();

        // Expected root value (depends on the inserted leaf and zero hashes)
        let expected_root = keccak_u256s_be_inputs(array![leaf, *zero_hashes[0]].span());
    // assert_eq!(root_with_ctx, expected_root);
    // assert_eq!(root, expected_root);
    }

    #[test]
    #[ignore]
    fn test_insert_multiple_leaves() {
        let mut tree = MerkleLib::new();

        let leaf1 = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef_u256;
        let leaf2 = 0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210_u256;

        tree.insert(leaf1);
        tree.insert(leaf2);

        let zero_hashes = zero_hashes();
        let root = tree.root_with_ctx(zero_hashes.clone());

        let intermediate = keccak_u256s_be_inputs(array![leaf1, leaf2].span());
        let expected_root = keccak_u256s_be_inputs(array![intermediate, *zero_hashes[1]].span());

        assert(root == expected_root, 'root does not match expected');
    }


    #[test]
    #[ignore]
    #[should_panic(expected: ('Merkle tree full',))]
    fn test_tree_full() {
        let mut tree = MerkleLib::new();
        let MAX_LEAVES = pow(2_u128, TREE_DEPTH.into()) - 1;
        let mut cur_idx = 0;
        loop {
            if (cur_idx == MAX_LEAVES) {
                break ();
            }
            tree.insert(0_u256);
            cur_idx += 1;
        };

        assert(tree.count == MAX_LEAVES.into(), 'Wrong tree count');

        tree.insert(0_u256);
    }
}
