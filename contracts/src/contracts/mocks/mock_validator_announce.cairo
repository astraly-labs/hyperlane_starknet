#[starknet::contract]
pub mod mock_validator_announce {
    use alexandria_bytes::{Bytes, BytesTrait};
    use alexandria_data_structures::array_ext::ArrayTraitExt;
    use core::poseidon::poseidon_hash_span;
    use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{
        HYPERLANE_ANNOUNCEMENT
    };
    use hyperlane_starknet::interfaces::IMockValidatorAnnounce;
    use hyperlane_starknet::interfaces::{IMailboxClientDispatcher, IMailboxClientDispatcherTrait};
    use hyperlane_starknet::utils::keccak256::{
        reverse_endianness, to_eth_signature, compute_keccak, ByteData, u64_word_size,
        u256_word_size, HASH_SIZE, bool_is_eth_signature_valid
    };
    use hyperlane_starknet::utils::store_arrays::StoreFelt252Array;

    use starknet::ContractAddress;
    use starknet::EthAddress;
    use starknet::secp256_trait::{Signature, signature_from_vrs};

    #[storage]
    struct Storage {
        mailboxclient: ContractAddress,
        domain: u32,
        storage_location: LegacyMap::<EthAddress, Array<felt252>>,
        replay_protection: LegacyMap::<felt252, bool>,
        validators: LegacyMap::<EthAddress, EthAddress>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ValidatorAnnouncement: ValidatorAnnouncement
    }

    #[derive(starknet::Event, Drop)]
    pub struct ValidatorAnnouncement {
        pub validator: EthAddress,
        pub storage_location: Array<felt252>
    }

    pub mod Errors {
        pub const REPLAY_PROTECTION_ERROR: felt252 = 'Announce already occured';
        pub const WRONG_SIGNER: felt252 = 'Wrong signer';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox_client: ContractAddress, _domain: u32) {
        self.mailboxclient.write(_mailbox_client);
        self.domain.write(_domain);
    }

    #[abi(embed_v0)]
    impl IValidatorAnnonceImpl of IMockValidatorAnnounce<ContractState> {
        fn announce(
            ref self: ContractState,
            _validator: EthAddress,
            mut _storage_location: Array<felt252>,
            _signature: Bytes
        ) -> bool {
            let felt252_validator: felt252 = _validator.into();
            let mut _input: Array<u256> = array![felt252_validator.into()];
            let mut u256_storage_location: Array<u256> = array![];
            loop {
                match _storage_location.pop_front() {
                    Option::Some(storage) => u256_storage_location.append(storage.into()),
                    Option::None(()) => { break (); },
                }
            };
            let replay_id = poseidon_hash_span(
                array![felt252_validator].concat(@_storage_location).span()
            );
            assert(!self.replay_protection.read(replay_id), Errors::REPLAY_PROTECTION_ERROR);
            let announcement_digest = self.get_announcement_digest(u256_storage_location);
            let signature: Signature = convert_to_signature(_signature);
            assert(
                bool_is_eth_signature_valid(announcement_digest, signature, _validator),
                Errors::WRONG_SIGNER
            );
            match find_validators_index(@self, _validator) {
                Option::Some(_) => {},
                Option::None(()) => {
                    let last_validator = find_last_validator(@self);
                    self.validators.write(last_validator, _validator);
                }
            };
            self.storage_location.write(_validator, _storage_location.clone());
            self
                .emit(
                    ValidatorAnnouncement {
                        validator: _validator, storage_location: _storage_location
                    }
                );
            true
        }

        fn get_announced_storage_locations(
            self: @ContractState, mut _validators: Span<EthAddress>
        ) -> Span<Span<felt252>> {
            let mut metadata = array![];
            loop {
                match _validators.pop_front() {
                    Option::Some(validator) => {
                        let validator_metadata = self.storage_location.read(*validator);
                        metadata.append(validator_metadata.span())
                    },
                    Option::None(()) => { break (); }
                }
            };
            metadata.span()
        }

        fn get_announced_validators(self: @ContractState) -> Span<EthAddress> {
            build_validators_array(self)
        }

        fn get_announcement_digest(
            self: @ContractState, mut _storage_location: Array<u256>
        ) -> u256 {
            let mailboxclient_address = self.mailboxclient.read();
            let domain = self.domain.read();
            let domain_hash = domain_hash(self, mailboxclient_address, domain);
            let mut byte_data_storage_location = array![];
            loop {
                match _storage_location.pop_front() {
                    Option::Some(storage) => {
                        byte_data_storage_location
                            .append(
                                ByteData { value: storage, size: u256_word_size(storage).into() }
                            );
                    },
                    Option::None(_) => { break (); }
                }
            };
            let hash = reverse_endianness(
                compute_keccak(
                    array![ByteData { value: domain_hash, size: HASH_SIZE }]
                        .concat(@byte_data_storage_location)
                        .span()
                )
            );
            to_eth_signature(hash)
        }
    }


    fn convert_to_signature(_signature: Bytes) -> Signature {
        let (_, r) = _signature.read_u256(0);
        let (_, s) = _signature.read_u256(32);
        let (_, v) = _signature.read_u8(64);
        signature_from_vrs(v.try_into().unwrap(), r, s)
    }


    fn domain_hash(self: @ContractState, _mailbox_address: ContractAddress, _domain: u32) -> u256 {
        let felt_address: felt252 = _mailbox_address.into();
        let mut input: Array<ByteData> = array![
            ByteData { value: _domain.into(), size: u64_word_size(_domain.into()).into() },
            ByteData {
                value: felt_address.into(), size: u256_word_size(felt_address.into()).into()
            },
            ByteData { value: HYPERLANE_ANNOUNCEMENT.into(), size: 22 }
        ];
        reverse_endianness(compute_keccak(input.span()))
    }


    fn find_validators_index(self: @ContractState, _validator: EthAddress) -> Option<EthAddress> {
        let mut current_validator: EthAddress = 0.try_into().unwrap();
        loop {
            let next_validator = self.validators.read(current_validator);
            if next_validator == _validator {
                break Option::Some(current_validator);
            } else if next_validator == 0.try_into().unwrap() {
                break Option::None(());
            }
            current_validator = next_validator;
        }
    }

    fn find_last_validator(self: @ContractState) -> EthAddress {
        let mut current_validator = self.validators.read(0.try_into().unwrap());
        loop {
            let next_validator = self.validators.read(current_validator);
            if next_validator == 0.try_into().unwrap() {
                break current_validator;
            }
            current_validator = next_validator;
        }
    }

    fn build_validators_array(self: @ContractState) -> Span<EthAddress> {
        let mut index = 0.try_into().unwrap();
        let mut validators = array![];
        loop {
            let validator = self.validators.read(index);
            if (validator == 0.try_into().unwrap()) {
                break ();
            }
            validators.append(validator);
            index = validator;
        };

        validators.span()
    }
}
