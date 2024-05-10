#[starknet::contract]
pub mod messageid_multisig_ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use core::ecdsa::check_ecdsa_signature;
    use starknet::eth_signature::is_eth_signature_valid;
    use starknet::EthAddress;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
     IMultisigIsm, IMultisigIsmDispatcher, IMultisigIsmDispatcherTrait,
        ModuleType, IInterchainSecurityModule, IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    };
    use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::CheckpointLib;
    use hyperlane_starknet::contracts::libs::multisig::message_id_ism_metadata::message_id_ism_metadata::MessageIdIsmMetadata;
    use starknet::ContractAddress;
    use starknet::secp256_trait::{Signature,signature_from_vrs};
    #[storage]
    struct Storage {}

    mod Errors {
        pub const NO_MULTISIG_THRESHOLD_FOR_MESSAGE: felt252 = 'No MultisigISM treshold present';
        pub const VERIFICATION_FAILED_THRESHOLD_NOT_REACHED: felt252 = 'Verify failed, < threshold';
    }
    impl IMessageidMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MESSAGE_ID_MULTISIG(starknet::get_contract_address())
        }

        fn verify(
            self: @ContractState,
            _metadata: Span<Bytes>,
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
                let signature = get_signature_at(_metadata.clone(), i);

                // we loop on the validators list public kew in order to find a match
                let mut cur_idx = 0;
                let is_signer_in_list = loop {
                    if (cur_idx == validators.len()) {
                        break false;
                    }
                    let signer = *validators.at(cur_idx).public_key;
                    if bool_is_eth_signature_valid(digest.into(), signature, signer.try_into().unwrap()) {
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

    fn digest(_metadata: Span<Bytes>, _message: Message) -> felt252 {
        let origin_merkle_tree_hook = MessageIdIsmMetadata::origin_merkle_tree_hook(_metadata.clone());
        let root = MessageIdIsmMetadata::root(_metadata.clone());
        let index = MessageIdIsmMetadata::index(_metadata.clone()); 
        CheckpointLib::digest(_message.origin,origin_merkle_tree_hook.into(), root.into(), index, MessageTrait::format_message(_message)).try_into().unwrap()
    }

    fn get_signature_at(_metadata: Span<Bytes>, _index: u32) -> Signature {
        let (v,r,s) = MessageIdIsmMetadata::signature_at(_metadata, _index); 
        signature_from_vrs(v.into(),r,s)

    }

    fn bool_is_eth_signature_valid(msg_hash: u256, signature: Signature, signer: EthAddress) -> bool {
        match is_eth_signature_valid(msg_hash, signature, signer) {
            Result::Ok(()) => true, 
            Result::Err(_) => false
        }
    }
}
