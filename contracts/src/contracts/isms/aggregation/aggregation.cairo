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
        pub const MODULES_ALREADY_STORED: felt252 = 'Modules already stored';
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


        /// Returns the set of ISMs responsible for verifying _message and the number of ISMs that must verify
        /// Dev: Can change based on the content of _message
        /// 
        /// # Arguments
        /// 
        /// * - `_message` - the message to consider
        /// 
        /// # Returns 
        /// 
        /// Span<ContractAddress> - The array of ISM addresses
        /// threshold - The number of ISMs needed to verify
        fn modules_and_threshold(
            self: @ContractState, _message: Message
        ) -> (Span<ContractAddress>, u8) {
            // THE USER CAN DEFINE HERE CONDITIONS FOR THE MODULE AND THRESHOLD SELECTION
            let threshold = self.threshold.read();
            (self.build_modules_span(), threshold)
        }


        /// Requires that m-of-n ISMs verify the provided interchain message.
        /// Dev: Can change based on the content of _message
        /// Dev: Reverts if threshold is not set
        /// 
        /// # Arguments
        /// 
        /// * - `_metadata` - encoded metadata (see aggregation_ism_metadata.cairo)
        /// * - `_message` - message structure containing relevant information (see message.cairo)
        /// 
        /// # Returns 
        /// 
        /// boolean - wheter the verification succeed or not.
        fn verify(self: @ContractState, _metadata: Bytes, _message: Message,) -> bool {
            let (isms, mut threshold) = self.modules_and_threshold(_message.clone());

            assert(threshold != 0, Errors::THRESHOLD_NOT_SET);
            let modules = self.build_modules_span();
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
            self.build_modules_span()
        }

        fn get_threshold(self: @ContractState) -> u8 {
            self.threshold.read()
        }

        /// Sets the ISM modules responsible for the verification
        /// Dev: reverts if module address is null
        /// Dev: Callable only by the owner
        /// 
        /// # Arguments
        /// 
        /// * - `_modules` - a span of module contract addresses
        /// 
        fn set_modules(ref self: ContractState, _modules: Span<ContractAddress>) {
            self.ownable.assert_only_owner();
            assert(!self.are_modules_stored(_modules), Errors::MODULES_ALREADY_STORED);
            let mut last_module = self.find_last_module();
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

        /// Sets the threshold for validation
        /// Dev: callable only by the owner
        /// 
        /// # Arguments
        /// 
        /// * - `_threshold` - The number of validator signatures needed
        fn set_threshold(ref self: ContractState, _threshold: u8) {
            self.ownable.assert_only_owner();
            self.threshold.write(_threshold);
        }
    }
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Helper:  finds the last module stored in the legacy map
        /// 
        /// # Returns
        /// 
        /// ContractAddress -the address of the last module stored. 
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
        /// Helper:  finds the index associated to a module in the legacy map
        /// 
        /// # Returns
        /// 
        /// Option<ContractAddress> - the contract if found, else None
        fn find_module_index(
            self: @ContractState, _module: ContractAddress
        ) -> Option<ContractAddress> {
            let mut current_module: ContractAddress = 0.try_into().unwrap();
            loop {
                let next_module = self.modules.read(current_module);
                if next_module == _module {
                    break Option::Some(current_module);
                } else if next_module == 0.try_into().unwrap() {
                    break Option::None(());
                }
                current_module = next_module;
            }
        }

        /// Helper:  determines if a span of modules are already stored in the Storage Mapping
        /// 
        /// # Returns
        /// 
        /// boolean - True if at least one module is stored
        fn are_modules_stored(self: @ContractState, _modules: Span<ContractAddress>) -> bool {
            let mut cur_idx = 0;
            let mut result = false;
            while cur_idx < _modules.len()
                && result == false {
                    let module = *_modules.at(cur_idx);
                    match self.find_module_index(module) {
                        Option::Some => result = true,
                        Option::None => {}
                    };
                    cur_idx += 1;
                };
            result
        }

        /// Helper:  Build a module span out of a storage map
        /// 
        /// # Returns
        /// 
        /// Span<ContractAddress> - a span of module addresses
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
}
