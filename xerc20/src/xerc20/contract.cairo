#[starknet::contract]
pub mod XERC20 {
    use crate::xerc20::component::XERC20Component;
    use openzeppelin_access::ownable::ownable::OwnableComponent;
    use openzeppelin_token::erc20::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use openzeppelin_utils::cryptography::{nonces::NoncesComponent, snip12::SNIP12Metadata};
    use starknet::{ClassHash, ContractAddress};

    // Ownable Component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // Nonces Component for ERC20Permit
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC20Component with Permit
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    // ISNIP12Metadata
    #[abi(embed_v0)]
    impl SNIP12MetadataExternalImpl =
        ERC20Component::SNIP12MetadataExternalImpl<ContractState>;
    // IERC20Permit
    #[abi(embed_v0)]
    impl ERC20PermitImpl = ERC20Component::ERC20PermitImpl<ContractState>;

    // XERC20Component
    component!(path: XERC20Component, storage: xerc20, event: XERC20Event);

    #[abi(embed_v0)]
    impl XERC20Impl = XERC20Component::XERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl XERC20GettersImpl = XERC20Component::XERC20GettersImpl<ContractState>;

    impl XERC20InternalImpl = XERC20Component::InternalImpl<ContractState>;

    // UpgradeableComponent
    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
        #[substorage(v0)]
        xerc20: XERC20Component::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
        #[flat]
        XERC20Event: XERC20Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'XERC20_Starknet'
        }
        fn version() -> felt252 {
            '0.1.0'
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, factory: ContractAddress,
    ) {
        self.ownable.initializer(factory);
        self.xerc20.initialize(factory);
        self.erc20.initializer(name, symbol);
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
        /// - This function can only be called by the owner.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgrades.upgrade(new_class_hash);
        }
    }
}
