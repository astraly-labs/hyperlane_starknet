#[starknet::contract]
pub mod messageid_multisig_ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use core::ecdsa::check_ecdsa_signature;
    use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::CheckpointLib;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::contracts::libs::multisig::message_id_ism_metadata::message_id_ism_metadata::MessageIdIsmMetadata;
    use hyperlane_starknet::interfaces::{
        IMultisigIsm, IMultisigIsmDispatcher, IMultisigIsmDispatcherTrait, ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait,
    };
    use starknet::ContractAddress;
    use starknet::EthAddress;
    use starknet::eth_signature::is_eth_signature_valid;
    use starknet::secp256_trait::{Signature, signature_from_vrs};
    #[storage]
    struct Storage {}

    mod Errors {
        pub const NO_MULTISIG_THRESHOLD_FOR_MESSAGE: felt252 = 'No MultisigISM treshold present';
        pub const NO_MATCH_FOR_SIGNATURE: felt252 = 'No match for given signature';
        pub const EMPTY_METADATA: felt252 = 'Empty metadata';
    }
    #[abi(embed_v0)]
    impl IMessageidMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MESSAGE_ID_MULTISIG(starknet::get_contract_address())
        }

        fn verify(
            self: @ContractState,
            _metadata: Bytes,
            _message: Message,
            _validator_configuration: ContractAddress,
        ) -> bool {
            assert(_metadata.clone().data().len() > 0, Errors::EMPTY_METADATA);
            let digest = digest(_metadata.clone(), _message.clone());
            let validator_configuration = IMultisigIsmDispatcher {
                contract_address: _validator_configuration
            };
            let (validators, threshold) = validator_configuration
                .validators_and_threshold(_message);
            assert(threshold > 0, Errors::NO_MULTISIG_THRESHOLD_FOR_MESSAGE);
            let mut matched_signatures = 0;
            let mut i = 0;

            // for each couple (sig_s, sig_r) extracted from the metadata
            loop {
                if (i == threshold) {
                    break ();
                }
                let signature = get_signature_at(_metadata.clone(), i);
                // we loop on the validators list public key in order to find a match
                let mut cur_idx = 0;
                let is_signer_in_list = loop {
                    if (cur_idx == validators.len()) {
                        break false;
                    }
                    let signer = *validators.at(cur_idx);
                    if bool_is_eth_signature_valid(digest, signature, signer) {
                        // we found a match
                        break true;
                    }
                    cur_idx += 1;
                };
                assert(is_signer_in_list, Errors::NO_MATCH_FOR_SIGNATURE);
                i += 1;
            };
            println!("matched_signatures: {}", matched_signatures);
            true
        }
    }

    fn digest(_metadata: Bytes, _message: Message) -> u256 {
        let origin_merkle_tree_hook = MessageIdIsmMetadata::origin_merkle_tree_hook(
            _metadata.clone()
        );
        let root = MessageIdIsmMetadata::root(_metadata.clone());
        let index = MessageIdIsmMetadata::index(_metadata.clone());
        CheckpointLib::digest(
            _message.origin,
            origin_merkle_tree_hook.into(),
            root.into(),
            index,
            MessageTrait::format_message(_message)
        )
    }

    fn get_signature_at(_metadata: Bytes, _index: u32) -> Signature {
        let (v, r, s) = MessageIdIsmMetadata::signature_at(_metadata, _index);
        signature_from_vrs(v.into(), r, s)
    }

    fn bool_is_eth_signature_valid(
        msg_hash: u256, signature: Signature, signer: EthAddress
    ) -> bool {
        match is_eth_signature_valid(msg_hash, signature, signer) {
            Result::Ok(()) => true,
            Result::Err(_) => false
        }
    }
}
