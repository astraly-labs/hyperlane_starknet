#[starknet::contract]
pub mod XERC20Factory {
    use core::num::traits::Zero;
    use crate::{
        factory::interface::IXERC20Factory,
        utils::enumerable_address_set::{
            EnumerableAddressSet, EnumerableAddressSetTrait, MutableEnumerableAddressSetTrait,
        },
        xerc20::interface::{IXERC20Dispatcher, IXERC20DispatcherTrait},
    };
    use openzeppelin_access::ownable::{
        interface::{IOwnableDispatcher, IOwnableDispatcherTrait}, ownable::OwnableComponent,
    };
    use starknet::{
        ClassHash, ContractAddress, SyscallResultTrait,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };

    // Ownable Component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        xerc20_class_hash: ClassHash,
        lockbox_class_hash: ClassHash,
        xerc20_to_lockbox: Map<ContractAddress, ContractAddress>,
        erc20_to_lockbox: Map<ContractAddress, ContractAddress>,
        lockbox_registry: EnumerableAddressSet,
        xerc20_registry: EnumerableAddressSet,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        XERC20Deployed: XERC20Deployed,
        LockboxDeployed: LockboxDeployed,
        XERC20ImplementationUpdated: XERC20ImplementationUpdated,
        LockboxImplementationUpdated: LockboxImplementationUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XERC20Deployed {
        pub xerc20: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LockboxDeployed {
        pub lockbox: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct XERC20ImplementationUpdated {
        pub class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LockboxImplementationUpdated {
        pub class_hash: ClassHash,
    }

    pub mod Errors {
        pub const CALLER_NOT_OWNER: felt252 = 'Caller is not the owner';
        pub const TOKEN_ADDRESS_ZERO: felt252 = 'Token address zero';
        pub const LOCKBOX_ALREADY_DEPLOYED: felt252 = 'Lockbox alread deployed';
        pub const INVALID_LENGTH: felt252 = 'Invalid length';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        xerc20_class_hash: ClassHash,
        lockbox_class_hash: ClassHash,
        owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.xerc20_class_hash.write(xerc20_class_hash);
        self.lockbox_class_hash.write(lockbox_class_hash);
    }

    #[abi(embed_v0)]
    impl XERC20FactoryImpl of IXERC20Factory<ContractState> {
        /// Deploys a XERC20 contract and set bridges and their limits.
        ///
        /// # Arguments
        ///
        /// - `name` a `ByteArray` representing the name of xerc20 token.
        /// - `symbol` a `ByteArray` representing the symbol of xerc20 token.
        /// - `minter_limits` a `Span<u256>` representing list of minting limits
        /// - `burner_limits` a `Span<u256>` representing list of burning limits.
        /// - `bridges` a `Span<ContractAddress>` representing list of bridges.
        ///
        /// # Requirements
        ///
        /// - `minter_limits`, `burner_limits` and `bridges`` needs to be paralel arrays that i-th
        /// index represents limits for the bridge at `bridges[i]`.
        ///
        /// # Returns
        ///
        /// A `ContractAddress` representing the deployed xerc20.
        fn deploy_xerc20(
            ref self: ContractState,
            name: ByteArray,
            symbol: ByteArray,
            minter_limits: Span<u256>,
            burner_limits: Span<u256>,
            bridges: Span<ContractAddress>,
        ) -> ContractAddress {
            let deployed_address = self
                ._deploy_xerc20(name, symbol, minter_limits, burner_limits, bridges);
            self.emit(XERC20Deployed { xerc20: deployed_address });
            deployed_address
        }

        /// Deploys a XERC20 lockbox and sets lockbox of given xerc20 token.
        ///
        /// # Arguments
        ///
        /// - `xerc20`  A `ContractAddress` representing the xerc20 token we want to deploy a
        /// lockbox for.
        /// - `base_token` A `ContractAddress` representing the base token that we want to lock.
        ///
        /// # Requirementes
        ///
        /// - `base_token` should be non-zero.
        /// - Caller must be the owner of xerc20 token.
        /// - Lockbox must not already deployed.
        ///
        /// # Returns
        ///
        /// A `ContractAddress` representing the deployed lockbox.
        fn deploy_lockbox(
            ref self: ContractState, xerc20: ContractAddress, base_token: ContractAddress,
        ) -> ContractAddress {
            assert(base_token.is_non_zero(), Errors::TOKEN_ADDRESS_ZERO);

            let xerc20_token_owner = IOwnableDispatcher { contract_address: xerc20 }.owner();
            assert(xerc20_token_owner == starknet::get_caller_address(), Errors::CALLER_NOT_OWNER);
            assert(
                self.xerc20_to_lockbox.entry(xerc20).read().is_zero(),
                Errors::LOCKBOX_ALREADY_DEPLOYED,
            );

            let deployed_address = self._deploy_lockbox(xerc20, base_token);
            self.emit(LockboxDeployed { lockbox: deployed_address });
            deployed_address
        }

        /// Updates the xerc20 class hash with `new_class_hash`.
        ///
        /// # Arguments
        ///
        /// - `new_class_hash` A `ClassHash` representing the implementation to update to.
        ///
        /// # Requirements
        ///
        /// - This function can only be called by the owner.
        fn set_xerc20_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.xerc20_class_hash.write(new_class_hash);
            self.emit(XERC20ImplementationUpdated { class_hash: new_class_hash });
        }

        /// Updates the lockbox class hash with `new_class_hash`.
        ///
        /// # Arguments
        ///
        /// - `new_class_hash` A `ClassHash` representing the implementation to update to.
        ///
        /// # Requirements
        ///
        /// - This function can only be called by the owner.
        fn set_lockbox_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.lockbox_class_hash.write(new_class_hash);
            self.emit(LockboxImplementationUpdated { class_hash: new_class_hash });
        }

        /// Returns `ClassHash` of xerc20 implementation used by this contract
        fn get_xerc20_class_hash(self: @ContractState) -> ClassHash {
            self.xerc20_class_hash.read()
        }

        /// Returns `ClassHash` of lockbox implementation used by this contract
        fn get_lockbox_class_hash(self: @ContractState) -> ClassHash {
            self.lockbox_class_hash.read()
        }

        /// Determines if a given `ContractAddress` is a xerc20 deployed by this factory or not.
        fn is_xerc20(self: @ContractState, xerc20: ContractAddress) -> bool {
            self.xerc20_registry.deref().contains(xerc20)
        }

        /// Determines if a given `ContractAddress` is a lockbox deployed by this factory or not.
        fn is_lockbox(self: @ContractState, lockbox: ContractAddress) -> bool {
            self.lockbox_registry.deref().contains(lockbox)
        }

        /// Returns all xerc20 tokens deployed by this factory.
        fn get_xerc20s(self: @ContractState) -> Array<ContractAddress> {
            self.xerc20_registry.deref().values()
        }

        /// Returns all lockboxes deployed by this factory.
        fn get_lockboxes(self: @ContractState) -> Array<ContractAddress> {
            self.lockbox_registry.deref().values()
        }

        /// Returns lockbox for given erc20 token.
        ///
        /// # Arguments
        ///
        /// - `erc20` A `ContractAddress` representing the token to query for lookbox.
        ///
        /// # Returns
        ///
        /// A `ContractAddress` representing the lockbox for given erc20 token. Returns address zero
        /// if no lockbox for the token.
        fn get_lockbox_for_erc20(self: @ContractState, erc20: ContractAddress) -> ContractAddress {
            self.erc20_to_lockbox.entry(erc20).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Internal function that deploys xerc20 tokens and set limits for the given bridges.
        fn _deploy_xerc20(
            ref self: ContractState,
            name: ByteArray,
            symbol: ByteArray,
            minter_limits: Span<u256>,
            burner_limits: Span<u256>,
            bridges: Span<ContractAddress>,
        ) -> ContractAddress {
            assert(
                minter_limits.len() == bridges.len() && bridges.len() == burner_limits.len(),
                Errors::INVALID_LENGTH,
            );
            // calculate the salt
            let mut serialized_data: Array<felt252> = array![];
            name.serialize(ref serialized_data);
            symbol.serialize(ref serialized_data);
            starknet::get_caller_address().serialize(ref serialized_data);
            let salt = core::poseidon::poseidon_hash_span(serialized_data.span());
            // prepare the constructor calldata
            let mut serialized_ctor_data: Array<felt252> = array![];
            name.serialize(ref serialized_ctor_data);
            symbol.serialize(ref serialized_ctor_data);
            starknet::get_contract_address().serialize(ref serialized_ctor_data);
            // deploy the xerc20 contract
            let (deployed_address, _) = starknet::syscalls::deploy_syscall(
                self.xerc20_class_hash.read(), salt, serialized_ctor_data.span(), false,
            )
                .unwrap_syscall();
            // update storage
            self.xerc20_registry.deref().add(deployed_address);
            // set the limits for given bridges
            let xerc20_dispatcher = IXERC20Dispatcher { contract_address: deployed_address };
            for i in 0..bridges.len() {
                xerc20_dispatcher
                    .set_limits(*bridges.at(i), *minter_limits.at(i), *burner_limits.at(i));
            };
            // transfer ownership to caller
            IOwnableDispatcher { contract_address: deployed_address }
                .transfer_ownership(starknet::get_caller_address());
            deployed_address
        }

        /// Internal function that deploys lockbox for given xerc20 token and base token.
        fn _deploy_lockbox(
            ref self: ContractState, xerc20: ContractAddress, base_token: ContractAddress,
        ) -> ContractAddress {
            // calculate the salt
            let salt = core::poseidon::poseidon_hash_span(
                array![xerc20.into(), base_token.into(), starknet::get_caller_address().into()]
                    .span(),
            );
            // deploy lockbox
            let (deployed_address, _) = starknet::syscalls::deploy_syscall(
                self.lockbox_class_hash.read(),
                salt,
                array![xerc20.into(), base_token.into()].span(),
                false,
            )
                .unwrap_syscall();
            // set lockbox on xerc20 contract
            IXERC20Dispatcher { contract_address: xerc20 }.set_lockbox(deployed_address);
            // update storage
            self.lockbox_registry.deref().add(deployed_address);
            self.xerc20_to_lockbox.entry(xerc20).write(deployed_address);
            self.erc20_to_lockbox.entry(base_token).write(deployed_address);
            deployed_address
        }
    }
}
