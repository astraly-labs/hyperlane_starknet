#[starknet::component]
pub mod XERC20Component {
    use crate::xerc20::interface::{Bridge, BridgeParameters, IXERC20, IXERC20Getters};
    use openzeppelin_access::ownable::ownable::{
        OwnableComponent, OwnableComponent::InternalTrait as OwnableInternalTrait,
    };
    use openzeppelin_token::erc20::{
        erc20::{ERC20Component, ERC20Component::InternalTrait as ERC20InternalTrait},
    };
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    /// The duration it takes for limits to fully replenish. A day.
    pub const DURATION: u64 = 60 * 60 * 24;
    pub const U256MAX_DIV_2: u256 = core::num::traits::Bounded::MAX / 2;

    #[storage]
    pub struct Storage {
        pub XERC20_factory: ContractAddress,
        pub XERC20_lockbox: ContractAddress,
        pub XERC20_bridges: Map<ContractAddress, BridgeNode>,
    }

    #[starknet::storage_node]
    pub struct BridgeNode {
        pub minter_params: BridgeParametersNode,
        pub burner_params: BridgeParametersNode,
    }

    #[starknet::storage_node]
    pub struct BridgeParametersNode {
        pub max_limit: u256,
        pub current_limit: u256,
        pub timestamp: u64,
        pub rate_per_second: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        LockboxSet: LockboxSet,
        BridgeLimitsSet: BridgeLimitsSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LockboxSet {
        pub lockbox: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeLimitsSet {
        pub minting_limit: u256,
        pub burning_limit: u256,
        #[key]
        pub bridge: ContractAddress,
    }

    pub mod Errors {
        pub const NOT_HIGH_ENOUGH_LIMITS: felt252 = 'User does not have enough limit';
        pub const CALLER_NOT_FACTORY: felt252 = 'Caller is not the factory';
        pub const LIMITS_TO_HIGH: felt252 = 'Limits too high';
    }

    #[embeddable_as(XERC20Impl)]
    pub impl XERC20<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of IXERC20<ComponentState<TContractState>> {
        /// Sets the lockbox.
        ///
        /// # Arguments
        ///
        /// - `lockbox` A `ContractAddress` representing the address of lockbox to set.
        ///
        /// # Requirements
        ///
        /// -Only callable by the factory of the token.
        fn set_lockbox(ref self: ComponentState<TContractState>, lockbox: ContractAddress) {
            assert(
                self.XERC20_factory.read() == starknet::get_caller_address(),
                Errors::CALLER_NOT_FACTORY,
            );
            self.XERC20_lockbox.write(lockbox);
            self.emit(LockboxSet { lockbox });
        }

        /// Sets burning & minting limit for a given bridge.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge to set limits for.
        /// - `minting_limit` A `u256` representing the minting limits for the bridge.
        /// - `burning_limit` A `u256` representing the burning limits for the bridge.
        ///
        /// # Requirements
        ///
        /// - Only callable by the owner of the token.
        /// - `minting_limit` and `burning_limit` should be lte to given treshold.
        fn set_limits(
            ref self: ComponentState<TContractState>,
            bridge: ContractAddress,
            minting_limit: u256,
            burning_limit: u256,
        ) {
            let ownable_comp = get_dep_component!(@self, Ownable);
            ownable_comp.assert_only_owner();
            assert(
                minting_limit <= U256MAX_DIV_2 && burning_limit <= U256MAX_DIV_2,
                Errors::LIMITS_TO_HIGH,
            );

            self.change_minter_limit(bridge, minting_limit);
            self.change_burner_limit(bridge, burning_limit);
            self.emit(BridgeLimitsSet { minting_limit, burning_limit, bridge });
        }

        /// Mints tokens for a user.
        ///
        /// # Arguments
        ///
        /// - `user` A `ContractAddress` representing the address who needs tokens minted.
        /// - `amount` A `u256` representing the amount of tokens being minted.
        fn mint(ref self: ComponentState<TContractState>, user: ContractAddress, amount: u256) {
            self.mint_with_caller(starknet::get_caller_address(), user, amount);
        }

        /// Burns tokens for a user.
        ///
        /// # Arguments
        ///
        /// - `user` A `ContractAddress` representing the address who needs tokens burned.
        /// - `amount` A `u256` representing the amount of tokens being burned.
        fn burn(ref self: ComponentState<TContractState>, user: ContractAddress, amount: u256) {
            let caller = starknet::get_caller_address();
            if caller != user {
                let mut erc20_comp = get_dep_component_mut!(ref self, ERC20);
                erc20_comp._spend_allowance(user, caller, amount);
            }
            self.burn_with_caller(caller, user, amount);
        }

        /// Returns the minting max limit for the bridge.
        ///
        /// # Arguments
        ///
        /// - `minter` A `ContractAddress` representing the bridge we are querying the limits of.
        fn minting_max_limit_of(
            self: @ComponentState<TContractState>, minter: ContractAddress,
        ) -> u256 {
            self.XERC20_bridges.entry(minter).minter_params.max_limit.read()
        }

        /// Returns the burning max limit for the bridge.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge we are querying the limits of.
        fn burning_max_limit_of(
            self: @ComponentState<TContractState>, bridge: ContractAddress,
        ) -> u256 {
            self.XERC20_bridges.entry(bridge).burner_params.max_limit.read()
        }

        /// Determines the minting current limit of given bridge.
        ///
        /// # Arguments
        ///
        /// - `minter` A `ContractAddress` representing the bridge we are querying the limits of.
        fn minting_current_limit_of(
            self: @ComponentState<TContractState>, minter: ContractAddress,
        ) -> u256 {
            let minter_params_storage_path = self
                .XERC20_bridges
                .entry(minter)
                .minter_params
                .deref();
            PureImpl::get_current_limit(
                minter_params_storage_path.current_limit.read(),
                minter_params_storage_path.max_limit.read(),
                minter_params_storage_path.rate_per_second.read(),
                minter_params_storage_path.timestamp.read(),
            )
        }

        /// Determines the burning current limit of given bridge.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge we are querying the limits of.
        fn burning_current_limit_of(
            self: @ComponentState<TContractState>, bridge: ContractAddress,
        ) -> u256 {
            let burner_params_storage_path = self
                .XERC20_bridges
                .entry(bridge)
                .burner_params
                .deref();
            PureImpl::get_current_limit(
                burner_params_storage_path.current_limit.read(),
                burner_params_storage_path.max_limit.read(),
                burner_params_storage_path.rate_per_second.read(),
                burner_params_storage_path.timestamp.read(),
            )
        }
    }

    #[embeddable_as(XERC20GettersImpl)]
    pub impl XERC20Getters<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IXERC20Getters<ComponentState<TContractState>> {
        /// Returns `ContractAddress` representing the address of the lockbox that is used by this
        /// xerc20 token.
        fn lockbox(self: @ComponentState<TContractState>) -> ContractAddress {
            self.XERC20_lockbox.read()
        }

        /// Returns `ContractAddress` representing the address of the factory that is used by this
        /// xerc20 token.
        fn factory(self: @ComponentState<TContractState>) -> ContractAddress {
            self.XERC20_factory.read()
        }

        /// Returns `Bridge` struct respresenting the parameters for given `bridge`.
        fn get_bridge(self: @ComponentState<TContractState>, bridge: ContractAddress) -> Bridge {
            let bridge_storage_path = self.XERC20_bridges.entry(bridge).deref();
            let minter_params_storage_path = bridge_storage_path.minter_params.deref();
            let burner_params_storage_path = bridge_storage_path.burner_params.deref();
            let minter_params = BridgeParameters {
                max_limit: minter_params_storage_path.max_limit.read(),
                current_limit: minter_params_storage_path.current_limit.read(),
                timestamp: minter_params_storage_path.timestamp.read(),
                rate_per_second: minter_params_storage_path.rate_per_second.read(),
            };
            let burner_params = BridgeParameters {
                max_limit: burner_params_storage_path.max_limit.read(),
                current_limit: burner_params_storage_path.current_limit.read(),
                timestamp: burner_params_storage_path.timestamp.read(),
                rate_per_second: burner_params_storage_path.rate_per_second.read(),
            };

            Bridge { minter_params, burner_params }
        }
    }

    #[generate_trait]
    pub impl PureImpl of PureTrait {
        /// Determines the new current limit.
        ///
        /// # Arguments
        ///
        /// - `limit` A `u256` representing the new limit.
        /// - `old_limit` A `u256` representing the old limit.
        /// - `current_limit` A `u256` representing the current limit.
        ///
        /// # Returns
        ///
        /// - A `u256` representing the new current limit.
        fn calculate_new_current_limit(limit: u256, old_limit: u256, current_limit: u256) -> u256 {
            if old_limit <= limit {
                let difference = limit - old_limit;
                return current_limit + difference;
            }

            let difference = old_limit - limit;
            if current_limit > difference {
                current_limit - difference
            } else {
                0
            }
        }

        /// Determines the current_limit.
        ///
        /// # Arguments
        ///
        /// - `current_limit` - A `u256` representing the current limit.
        /// - `max_limit` A `u256` representing the max limit.
        /// - `is_minter` A `bool` flag representing the calculation is done for minter params or
        /// burner.
        ///
        /// # Returns
        ///
        /// - A `u256`  representing the current limit
        fn get_current_limit(
            current_limit: u256, max_limit: u256, rate_per_second: u256, timestamp: u64,
        ) -> u256 {
            if current_limit == max_limit {
                return current_limit;
            }

            let current_timestamp = starknet::get_block_timestamp();
            if timestamp + DURATION <= current_timestamp {
                return max_limit;
            }
            let time_delta = current_timestamp - timestamp;
            let calculated_limit = current_limit + (time_delta.into() * rate_per_second);
            if calculated_limit > max_limit {
                max_limit
            } else {
                calculated_limit
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Internal function to initialize the component.
        fn initialize(ref self: ComponentState<TContractState>, factory: ContractAddress) {
            self.XERC20_factory.write(factory);
        }

        /// Internal function for burning tokens.
        fn burn_with_caller(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            user: ContractAddress,
            amount: u256,
        ) {
            if caller != self.XERC20_lockbox.read() {
                let current_limit = self.burning_current_limit_of(caller);
                assert(current_limit >= amount, Errors::NOT_HIGH_ENOUGH_LIMITS);
                self.use_burner_limits(caller, amount);
            }
            let mut erc20_comp = get_dep_component_mut!(ref self, ERC20);
            erc20_comp.burn(user, amount);
        }

        /// Internal function for minting tokens.
        fn mint_with_caller(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            user: ContractAddress,
            amount: u256,
        ) {
            if caller != self.XERC20_lockbox.read() {
                let current_limit = self.minting_current_limit_of(caller);
                assert(current_limit >= amount, Errors::NOT_HIGH_ENOUGH_LIMITS);
                self.use_minter_limits(caller, amount);
            }
            let mut erc20_comp = get_dep_component_mut!(ref self, ERC20);
            erc20_comp.mint(user, amount);
        }

        /// Consumes the minter limits from `bridge` by `change` amount.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge to consume limits from.
        /// - `change` A `u256` representing the change in the limit.
        ///
        /// # Requirements
        ///
        /// - `change` should be lte to actual limit.
        fn use_minter_limits(
            ref self: ComponentState<TContractState>, bridge: ContractAddress, change: u256,
        ) {
            let current_limit = self.minting_current_limit_of(bridge);
            let minter_params_storage_path = self
                .XERC20_bridges
                .entry(bridge)
                .minter_params
                .deref();
            minter_params_storage_path.current_limit.write(current_limit - change);
            minter_params_storage_path.timestamp.write(starknet::get_block_timestamp());
        }

        /// Consumes the burner limits from `bridge` by `change` amount.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge to consume limits from.
        /// - `change` A `u256` representing the change in the limit.
        ///
        /// # Requirements
        ///
        /// - `change` should be lte to actual limit.
        fn use_burner_limits(
            ref self: ComponentState<TContractState>, bridge: ContractAddress, change: u256,
        ) {
            let current_limit = self.burning_current_limit_of(bridge);
            let burner_params_storage_path = self
                .XERC20_bridges
                .entry(bridge)
                .burner_params
                .deref();
            burner_params_storage_path.current_limit.write(current_limit - change);
            burner_params_storage_path.timestamp.write(starknet::get_block_timestamp());
        }

        /// Updates the minting limits of given bridge.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge whos limit is being changed.
        /// - `limit` A `u256` new limit value to set.
        fn change_minter_limit(
            ref self: ComponentState<TContractState>, bridge: ContractAddress, limit: u256,
        ) {
            let minter_params_storage_path = self
                .XERC20_bridges
                .entry(bridge)
                .minter_params
                .deref();
            let old_limit = minter_params_storage_path.max_limit.read();
            let current_limit = self.minting_current_limit_of(bridge);
            minter_params_storage_path.max_limit.write(limit);
            let new_current_limit = PureImpl::calculate_new_current_limit(
                limit, old_limit, current_limit,
            );
            minter_params_storage_path.current_limit.write(new_current_limit);
            minter_params_storage_path.rate_per_second.write(limit / DURATION.into());
            minter_params_storage_path.timestamp.write(starknet::get_block_timestamp());
        }

        /// Updates the burning limits of given bridge.
        ///
        /// # Arguments
        ///
        /// - `bridge` A `ContractAddress` representing the bridge whos limit is being changed.
        /// - `limit` A `u256` new limit value to set.
        fn change_burner_limit(
            ref self: ComponentState<TContractState>, bridge: ContractAddress, limit: u256,
        ) {
            let burner_params_storage_path = self
                .XERC20_bridges
                .entry(bridge)
                .burner_params
                .deref();
            let old_limit = burner_params_storage_path.max_limit.read();
            let current_limit = self.burning_current_limit_of(bridge);

            burner_params_storage_path.max_limit.write(limit);
            let new_current_limit = PureImpl::calculate_new_current_limit(
                limit, old_limit, current_limit,
            );
            burner_params_storage_path.current_limit.write(new_current_limit);
            burner_params_storage_path.rate_per_second.write(limit / DURATION.into());
            burner_params_storage_path.timestamp.write(starknet::get_block_timestamp());
        }
    }
}

