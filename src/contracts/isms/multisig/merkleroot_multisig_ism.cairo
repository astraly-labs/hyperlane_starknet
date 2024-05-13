#[starknet::contract]
pub mod merkleroot_multisig_ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};


    use core::ecdsa::check_ecdsa_signature;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IMultisigIsm, IMultisigIsmDispatcher, IMultisigIsmDispatcherTrait, ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait,
    };

    use starknet::ContractAddress;
    #[storage]
    struct Storage {}

    mod Errors {
        pub const NO_MULTISIG_THRESHOLD_FOR_MESSAGE: felt252 = 'No MultisigISM treshold present';
        pub const VERIFICATION_FAILED_THRESHOLD_NOT_REACHED: felt252 = 'Verify failed, < threshold';
    }

    #[abi(embed_v0)]
    impl IMerklerootMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MERKLE_ROOT_MULTISIG(starknet::get_contract_address())
        }

        fn verify(
            self: @ContractState,
            _metadata: Bytes,
            _message: Message,
            _validator_configuration: ContractAddress
        ) -> bool {
            let digest = digest(_metadata.clone(), _message.clone());
            let validator_configuration = IMultisigIsmDispatcher {
                contract_address: _validator_configuration
            };
            let (validators, threshold) = validator_configuration
                .validators_and_threshold(_message);
            assert(threshold > 0, Errors::NO_MULTISIG_THRESHOLD_FOR_MESSAGE);
            let validator_count = validators.len();
            let mut unmatched_signatures = 0;
            let mut matched_signatures = 0;
            let mut i = 0;

            // for each couple (sig_s, sig_r) extracted from the metadata
            loop {
                if (i == threshold) {
                    break ();
                }
                let (signature_r, signature_s) = get_signature_at(_metadata.clone(), i);

                // we loop on the validators list public kew in order to find a match
                let mut cur_idx = 0;
                let is_signer_in_list = loop {
                    if (cur_idx == validators.len()) {
                        break false;
                    }
                    let signer = *validators.at(cur_idx).address;
                    if check_ecdsa_signature(digest, signer.try_into().unwrap(), signature_r, signature_s) {
                        // we found a match
                        break true;
                    }
                    cur_idx += 1;
                };
                if (!is_signer_in_list) {
                    unmatched_signatures += 1;
                } else {
                    matched_signatures += 1;
                }
                assert(
                    unmatched_signatures < validator_count - threshold,
                    Errors::VERIFICATION_FAILED_THRESHOLD_NOT_REACHED
                );
                i += 1;
            };
            assert(
                matched_signatures >= threshold, Errors::VERIFICATION_FAILED_THRESHOLD_NOT_REACHED
            );
            true
        }
    }

    fn digest(_metadata: Bytes, _message: Message) -> felt252 {
        return 0;
    }

    fn get_signature_at(_metadata: Bytes, index: u32) -> (felt252, felt252) {
        (0, 0)
    }
}
