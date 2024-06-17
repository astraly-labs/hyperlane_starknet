#[starknet::contract]
pub mod merkleroot_multisig_ism {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};


    use core::ecdsa::check_ecdsa_signature;
    use hyperlane_starknet::contracts::hooks::merkle_tree_hook::merkle_tree_hook::InternalImpl;
    use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::CheckpointLib;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::contracts::libs::multisig::merkleroot_ism_metadata::merkleroot_ism_metadata::MerkleRootIsmMetadata;
    use hyperlane_starknet::interfaces::{
        ModuleType, IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, IValidatorConfiguration,
    };
    use hyperlane_starknet::utils::keccak256::{ByteData, HASH_SIZE};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::ContractAddress;
    use starknet::EthAddress;
    use starknet::eth_signature::is_eth_signature_valid;
    use starknet::secp256_trait::{Signature, signature_from_vrs};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        validators: LegacyMap<u32, EthAddress>,
        threshold: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    mod Errors {
        pub const NO_MULTISIG_THRESHOLD_FOR_MESSAGE: felt252 = 'No MultisigISM treshold present';
        pub const INVALID_MERKLE_INDEX: felt252 = 'Invalid merkle index metadata';
        pub const NO_MATCH_FOR_SIGNATURE: felt252 = 'No match for given signature';
        pub const EMPTY_METADATA: felt252 = 'Empty metadata';
        pub const VALIDATOR_ADDRESS_CANNOT_BE_NULL: felt252 = 'Validator address cannot be 0';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress) {
        self.ownable.initializer(_owner);
    }

    #[abi(embed_v0)]
    impl IMerklerootMultisigIsmImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::MERKLE_ROOT_MULTISIG(starknet::get_contract_address())
        }

        fn verify(self: @ContractState, _metadata: Bytes, _message: Message,) -> bool {
            assert(_metadata.clone().size() > 0, Errors::EMPTY_METADATA);
            let digest = digest(_metadata.clone(), _message.clone());
            let (validators, threshold) = self.validators_and_threshold(_message);
            assert(threshold > 0, Errors::NO_MULTISIG_THRESHOLD_FOR_MESSAGE);
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
            true
        }
    }


    #[abi(embed_v0)]
    impl IValidatorConfigurationImpl of IValidatorConfiguration<ContractState> {
        fn get_validators(self: @ContractState) -> Span<EthAddress> {
            build_validators_span(self)
        }

        fn get_threshold(self: @ContractState) -> u32 {
            self.threshold.read()
        }

        fn set_validators(ref self: ContractState, _validators: Span<EthAddress>) {
            self.ownable.assert_only_owner();
            let mut cur_idx = 0;

            loop {
                if (cur_idx == _validators.len()) {
                    break ();
                }
                let validator = *_validators.at(cur_idx);
                assert(
                    validator != 0.try_into().unwrap(), Errors::VALIDATOR_ADDRESS_CANNOT_BE_NULL
                );
                self.validators.write(cur_idx.into(), validator);
                cur_idx += 1;
            }
        }

        fn set_threshold(ref self: ContractState, _threshold: u32) {
            self.ownable.assert_only_owner();
            self.threshold.write(_threshold);
        }

        fn validators_and_threshold(
            self: @ContractState, _message: Message
        ) -> (Span<EthAddress>, u32) {
            // USER CONTRACT DEFINITION HERE
            // USER CAN SPECIFY VALIDATORS SELECTION CONDITIONS
            let threshold = self.threshold.read();
            (build_validators_span(self), threshold)
        }
    }

    fn digest(_metadata: Bytes, _message: Message) -> u256 {
        assert(
            MerkleRootIsmMetadata::message_index(
                _metadata.clone()
            ) <= MerkleRootIsmMetadata::signed_index(_metadata.clone()),
            Errors::INVALID_MERKLE_INDEX
        );
        let origin_merkle_tree_hook = MerkleRootIsmMetadata::origin_merkle_tree_hook(
            _metadata.clone()
        );
        let signed_index = MerkleRootIsmMetadata::signed_index(_metadata.clone());
        let signed_message_id = MerkleRootIsmMetadata::signed_message_id(_metadata.clone());
        let (id, _) = MessageTrait::format_message(_message.clone());
        let proof = MerkleRootIsmMetadata::proof(_metadata.clone());
        let message_index = MerkleRootIsmMetadata::message_index(_metadata.clone());
        let mut cur_idx = 0;
        let mut formatted_proof = array![];
        loop {
            if (cur_idx == proof.len()) {
                break ();
            }
            formatted_proof.append(ByteData { value: *proof.at(cur_idx), size: HASH_SIZE });
            cur_idx += 1;
        };
        let signed_root = InternalImpl::_branch_root(
            ByteData { value: id, size: HASH_SIZE }, formatted_proof.span(), message_index.into()
        );
        CheckpointLib::digest(
            _message.origin,
            origin_merkle_tree_hook.into(),
            signed_root.into(),
            signed_index,
            signed_message_id
        )
    }

    fn get_signature_at(_metadata: Bytes, _index: u32) -> Signature {
        let (v, r, s) = MerkleRootIsmMetadata::signature_at(_metadata, _index);
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

    fn build_validators_span(self: @ContractState) -> Span<EthAddress> {
        let mut validators = ArrayTrait::new();
        let mut cur_idx = 0;
        loop {
            let validator = self.validators.read(cur_idx);
            if (validator == 0.try_into().unwrap()) {
                break ();
            }
            validators.append(validator);
            cur_idx += 1;
        };
        validators.span()
    }
}
