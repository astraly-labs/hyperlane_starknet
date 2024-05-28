
#[starknet::interface]
pub trait IPausableIsm<TContractState> {
    fn pause(ref self: TContractState); 

    fn unpause(ref self: TContractState);
}


#[starknet::contract]
pub mod pausable {
    use alexandria_bytes::Bytes;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use super::{IPausableIsm, IPausableIsmDispatcher, IPausableIsmDispatcherTrait,};
    use hyperlane_starknet::interfaces::{ModuleType,
        IInterchainSecurityModule, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{ContractAddress, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;



    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        PausableEvent: PausableComponent::Event,
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
    impl IInterchainSecurityModuleImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::NULL(())
        }

        fn verify(self: @ContractState,_metadata: Bytes, _message: Message) -> bool {
            self.pausable.assert_not_paused();
            true
        }

    }

    #[abi(embed_v0)]
    impl IPausableIsmImpl of IPausableIsm<ContractState> {
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable._pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable._unpause();
        }
    }
}
