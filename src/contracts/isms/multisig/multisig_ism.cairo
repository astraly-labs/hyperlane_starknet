#[starknet::contract]
pub mod multisig_ism {
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::IMultisigIsm;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::eth_address::EthAddress;
    use starknet::{ContractAddress, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    type Index = felt252;


    #[storage]
    struct Storage {
        validators: LegacyMap<u32, EthAddress>,
        threshold: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
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


    mod Errors {
        pub const VALIDATOR_ADDRESS_CANNOT_BE_NULL: felt252 = 'Validator address cannot be 0';
    }

    #[abi(embed_v0)]
    impl IMultisigIsmImpl of IMultisigIsm<ContractState> {
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
