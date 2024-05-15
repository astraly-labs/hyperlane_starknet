#[starknet::contract]
pub mod validator_announce {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::keccak::keccak_u256s_be_inputs;
    use hyperlane_starknet::contracts::libs::checkpoint_lib::checkpoint_lib::{
        HYPERLANE_ANNOUNCEMENT, ETH_SIGNED_MESSAGE
    };
    use hyperlane_starknet::interfaces::IValidatorAnnounce;
    use hyperlane_starknet::interfaces::{IMailboxClientDispatcher, IMailboxClientDispatcherTrait};
    use hyperlane_starknet::utils::keccak256::reverse_endianness;
    use hyperlane_starknet::utils::store_arrays::StoreFelt252Array;

    use starknet::ContractAddress;
    use starknet::EthAddress;
    use starknet::eth_signature::is_eth_signature_valid;
    use starknet::secp256_trait::{Signature, signature_from_vrs};

    #[storage]
    struct Storage {
        mailboxclient: ContractAddress,
        storage_location: LegacyMap::<EthAddress, Array<felt252>>,
        replay_protection: LegacyMap::<u256, bool>,
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
        pub storage_location: felt252
    }

    pub mod Errors {
        pub const REPLAY_PROTECTION_ERROR: felt252 = 'Announce already occured';
        pub const WRONG_SIGNER: felt252 = 'Wrong signer';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox_client: ContractAddress) {
        self.mailboxclient.write(_mailbox_client);
    }

    #[abi(embed_v0)]
    impl IValidatorAnnonceImpl of IValidatorAnnounce<ContractState> {
        fn announce(
            ref self: ContractState,
            _validator: EthAddress,
            _storage_location: felt252,
            _signature: Bytes
        ) -> bool {
            let felt252_validator: felt252 = _validator.into();
            let mut input: Array<u256> = array![
                felt252_validator.into(), _storage_location.into(),
            ];
            let replay_id = keccak_hash(input.span());
            assert(!self.replay_protection.read(replay_id), Errors::REPLAY_PROTECTION_ERROR);
            let announcement_digest = self.get_announcement_digest(_storage_location);
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
            let mut storage_locations = self.storage_location.read(_validator);
            storage_locations.append(_storage_location);
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
        fn get_announcement_digest(self: @ContractState, _storage_location: felt252) -> u256 {
            let domain_hash = domain_hash(self);
            let mut input: Array<u256> = array![
                ETH_SIGNED_MESSAGE.into(), domain_hash.into(), _storage_location.into(),
            ];
            let hash = keccak_u256s_be_inputs(input.span());
            reverse_endianness(hash)
        }
    }


    fn convert_to_signature(_signature: Bytes) -> Signature {
        let (_, r) = _signature.read_u256(0);
        let (_, s) = _signature.read_u256(32);
        let (_, v) = _signature.read_u256(64);
        signature_from_vrs(v.try_into().unwrap(), r, s)
    }
    fn keccak_hash(_input: Span<u256>) -> u256 {
        let hash = keccak_u256s_be_inputs(_input);
        reverse_endianness(hash)
    }


    fn domain_hash(self: @ContractState) -> u256 {
        let mailboxclient = IMailboxClientDispatcher {
            contract_address: self.mailboxclient.read()
        };
        let mailboxclient_address: felt252 = self.mailboxclient.read().try_into().unwrap();
        let mut input: Array<u256> = array![
            mailboxclient.get_local_domain().into(),
            mailboxclient_address.try_into().unwrap(),
            HYPERLANE_ANNOUNCEMENT.into()
        ];
        let hash = keccak_u256s_be_inputs(input.span());
        reverse_endianness(hash)
    }


    fn bool_is_eth_signature_valid(
        msg_hash: u256, signature: Signature, signer: EthAddress
    ) -> bool {
        match is_eth_signature_valid(msg_hash, signature, signer) {
            Result::Ok(()) => true,
            Result::Err(_) => false
        }
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
