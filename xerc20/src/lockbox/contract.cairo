#[starknet::contract]
pub mod XERC20Lockbox {
    use crate::lockbox::component::XERC20LockboxComponent;
    use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ClassHash, ContractAddress};

    /// XERC20Lockbox Component
    component!(path: XERC20LockboxComponent, storage: lockbox, event: XERC20LockboxEvent);

    #[abi(embed_v0)]
    impl XERC20LockboxImpl = XERC20LockboxComponent::XERC20Lockbox<ContractState>;
    #[abi(embed_v0)]
    impl XERC20LockboxGettersImpl =
        XERC20LockboxComponent::XERC20LockboxGettersImpl<ContractState>;
    impl XERC20LockboxInternalImpl = XERC20LockboxComponent::InternalImpl<ContractState>;

    // UpgradeableComponent
    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        lockbox: XERC20LockboxComponent::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        XERC20LockboxEvent: XERC20LockboxComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, xerc20: ContractAddress, erc20: ContractAddress) {
        self.lockbox.initialize(xerc20, erc20);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the implementation used by this contract.
        ///
        /// # Arguments
        ///
        /// - `new_class_hash` A `ClassHash` representing the implementation to update to.
        ///
        /// # Requirements
        ///
        /// - This function can only be called by the xerc20 owner.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let ownable_dispatcher = IOwnableDispatcher { contract_address: self.lockbox.xerc20() };
            assert(
                ownable_dispatcher.owner() == starknet::get_caller_address(),
                'Caller not XERC20 owner',
            );
            self.upgrades.upgrade(new_class_hash);
        }
    }
}
