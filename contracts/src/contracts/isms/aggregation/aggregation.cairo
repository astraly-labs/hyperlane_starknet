#[starknet::contract]
pub mod aggregation {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::libs::aggregation_ism_metadata::aggregation_ism_metadata::AggregationIsmMetadata;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IAggregationDispatcher, IAggregation, IAggregationDispatcherTrait, ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ContractAddress, contract_address_const};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        modules: LegacyMap::<ContractAddress, ContractAddress>,
        threshold: u8,
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


    pub mod Errors {
        pub const VERIFICATION_FAILED: felt252 = 'Verification failed';
        pub const THRESHOLD_NOT_REACHED: felt252 = 'Threshold not reached';
        pub const MODULE_ADDRESS_CANNOT_BE_NULL: felt252 = 'Module address cannot be null';
        pub const THRESHOLD_NOT_SET: felt252 = 'Threshold not set';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress) {
        self.ownable.initializer(_owner);
    }


    #[abi(embed_v0)]
    impl IAggregationImpl of IAggregation<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::AGGREGATION(starknet::get_contract_address())
        }

        fn modules_and_threshold(
            self: @ContractState, _message: Message
        ) -> (Span<ContractAddress>, u8) {
            // THE USER CAN DEFINE HERE CONDITIONS FOR THE MODULE AND THRESHOLD SELECTION
            let threshold = self.threshold.read();
            (build_modules_span(self), threshold)
        }

        fn verify(self: @ContractState, _metadata: Bytes, _message: Message,) -> bool {
            let (isms, mut threshold) = self.modules_and_threshold(_message.clone());

            assert(threshold != 0, Errors::THRESHOLD_NOT_SET);
            let modules = build_modules_span(self);
            let mut cur_idx: u8 = 0;
            loop {
                if (threshold == 0) {
                    break ();
                }
                if (cur_idx.into() == isms.len()) {
                    break ();
                }
                if (!AggregationIsmMetadata::has_metadata(_metadata.clone(), cur_idx)) {
                    cur_idx += 1;
                    continue;
                }
                let ism = IInterchainSecurityModuleDispatcher {
                    contract_address: *modules.at(cur_idx.into())
                };

                let metadata = AggregationIsmMetadata::metadata_at(_metadata.clone(), cur_idx);
                assert(ism.verify(metadata, _message.clone()), Errors::VERIFICATION_FAILED);
                threshold -= 1;
                cur_idx += 1;
            };
            assert(threshold == 0, Errors::THRESHOLD_NOT_REACHED);
            true
        }

        fn get_modules(self: @ContractState) -> Span<ContractAddress> {
            build_modules_span(self)
        }

        fn get_threshold(self: @ContractState) -> u8 {
            self.threshold.read()
        }

        fn set_modules(ref self: ContractState, _modules: Span<ContractAddress>) {
            self.ownable.assert_only_owner();
            let mut last_module = find_last_module(@self);
            let mut cur_idx = 0;
            loop {
                if (cur_idx == _modules.len()) {
                    break ();
                }
                let module = *_modules.at(cur_idx);
                assert(
                    module != contract_address_const::<0>(), Errors::MODULE_ADDRESS_CANNOT_BE_NULL
                );
                self.modules.write(last_module, module);
                cur_idx += 1;
                last_module = module;
            }
        }

        fn set_threshold(ref self: ContractState, _threshold: u8) {
            self.ownable.assert_only_owner();
            self.threshold.write(_threshold);
        }
    }

    fn find_last_module(self: @ContractState) -> ContractAddress {
        let mut current_module = self.modules.read(contract_address_const::<0>());
        loop {
            let next_module = self.modules.read(current_module);
            if next_module == contract_address_const::<0>() {
                break current_module;
            }
            current_module = next_module;
        }
    }

    fn build_modules_span(self: @ContractState) -> Span<ContractAddress> {
        let mut cur_address = contract_address_const::<0>();
        let mut modules = array![];
        loop {
            let next_address = self.modules.read(cur_address);
            if (next_address == contract_address_const::<0>()) {
                break ();
            }
            modules.append(next_address);
            cur_address = next_address
        };
        modules.span()
    }
}
