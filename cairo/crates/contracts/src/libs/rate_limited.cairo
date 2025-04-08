#[starknet::interface]
pub trait IRateLimited<TState> {
    fn max_capacity(self: @TState) -> u256;
    fn calculate_current_level(self: @TState) -> u256;
    fn set_refill_rate(ref self: TState, capacity: u256) -> u256;
    fn validate_and_consume_filled_level(ref self: TState, consumed_amount: u256) -> u256;
    // Getters
    fn filled_level(self: @TState) -> u256;
    fn refill_rate(self: @TState) -> u256;
    fn last_updated(self: @TState) -> u64;
}

#[starknet::component]
pub mod RateLimitedComponent {
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalTrait as OwnableInternalTrait,
    };
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    // A day
    pub const DURATION: u64 = 60 * 60 * 24;

    #[storage]
    pub struct Storage {
        filled_level: u256,
        refill_rate: u256,
        last_updated: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RateLimitSet: RateLimitSet,
        ConsumedFilledLevel: ConsumedFilledLevel,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RateLimitSet {
        pub old_capacity: u256,
        pub new_capacity: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConsumedFilledLevel {
        pub filled_level: u256,
        pub last_updated: u64,
    }

    pub mod Errors {
        pub const RATE_LIMIT_EXCEEDED: felt252 = 'RateLimit exceeded';
        pub const RATE_LIMIT_NOT_SET: felt252 = 'RateLimit not set!';
        pub const CAPACITY_LT_DURATION: felt252 = 'Capacity must gte to duration!';
    }

    #[embeddable_as(RateLimited)]
    pub impl RateLimitedImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of super::IRateLimited<ComponentState<TContractState>> {
        /// Returns a `u256` representing the max capacity at which the bucket will no longer fill.
        fn max_capacity(self: @ComponentState<TContractState>) -> u256 {
            self.refill_rate.read() * DURATION.into()
        }

        /// Calculates the adjusted fill level based on time.
        ///
        /// # Returns
        ///
        /// A `u256` representing the current level.
        fn calculate_current_level(self: @ComponentState<TContractState>) -> u256 {
            let capacity = self.max_capacity();
            assert(capacity > 0, Errors::RATE_LIMIT_NOT_SET);

            let current_timestamp = starknet::get_block_timestamp();
            let last_updated = self.last_updated.read();
            if current_timestamp > last_updated + DURATION {
                return capacity;
            }

            let replenished_level = self.filled_level.read() + self.calculate_refilled_amount();
            if replenished_level > capacity {
                capacity
            } else {
                replenished_level
            }
        }

        /// Sets the refill rate based on the given capacity.
        ///
        /// # Arguments
        ///
        /// - `capacity` - A `u256` representing the new maximum capacity to set.
        ///
        /// # Returns
        ///
        /// A `u256` representing the new refill rate.
        fn set_refill_rate(ref self: ComponentState<TContractState>, capacity: u256) -> u256 {
            let ownable_comp = get_dep_component!(@self, Ownable);
            ownable_comp.assert_only_owner();
            self._set_refill_rate(capacity)
        }

        /// Validates the amount and decreases the current capacity.
        ///
        /// # Arguments
        ///
        /// - `consumed_amount` - A `u256` representing the amount to consume from the fill level.
        ///
        /// # Returns
        ///
        /// A `u256` representing the new filled level.
        fn validate_and_consume_filled_level(
            ref self: ComponentState<TContractState>, consumed_amount: u256,
        ) -> u256 {
            let adjusted_filled_level = self.calculate_current_level();
            assert(consumed_amount <= adjusted_filled_level, Errors::RATE_LIMIT_EXCEEDED);

            let filled_level = adjusted_filled_level - consumed_amount;
            self.filled_level.write(filled_level);
            let last_updated = starknet::get_block_timestamp();
            self.last_updated.write(last_updated);
            self.emit(ConsumedFilledLevel { filled_level, last_updated });
            filled_level
        }

        /// Returns a `u256` representing the filled level.
        fn filled_level(self: @ComponentState<TContractState>) -> u256 {
            self.filled_level.read()
        }

        /// Returns a `u256` representing the refill rate.
        fn refill_rate(self: @ComponentState<TContractState>) -> u256 {
            self.refill_rate.read()
        }

        /// Returns a `u64` representing the last updated timestamp.
        fn last_updated(self: @ComponentState<TContractState>) -> u64 {
            self.last_updated.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Internal function to initialize the component.
        fn initialize(
            ref self: ComponentState<TContractState>, capacity: u256, owner: ContractAddress,
        ) {
            assert(capacity >= DURATION.into(), Errors::CAPACITY_LT_DURATION);

            let mut ownable_comp = get_dep_component_mut!(ref self, Ownable);
            ownable_comp.initializer(owner);

            self._set_refill_rate(capacity);
            self.filled_level.write(capacity);
        }

        /// Calculates the refilled amount based on time and refill rate.
        ///
        /// To calculate:
        ///   elapsed = timestamp - last_updated
        ///   refill_rate = capacity / DURATION
        ///   refilled = elapsed * refill_rate
        ///
        /// # Returns
        ///
        /// A `u256` representing the refilled amount.
        fn calculate_refilled_amount(self: @ComponentState<TContractState>) -> u256 {
            let elapsed = starknet::get_block_timestamp() - self.last_updated.read();
            elapsed.into() * self.refill_rate.read()
        }

        /// Internal function to set the refill rate based on the given capacity.
        fn _set_refill_rate(ref self: ComponentState<TContractState>, capacity: u256) -> u256 {
            let old_refill_rate = self.refill_rate.read();
            let new_refill_rate = capacity / DURATION.into();
            self.refill_rate.write(new_refill_rate);
            self
                .emit(
                    RateLimitSet { old_capacity: old_refill_rate, new_capacity: new_refill_rate },
                );
            new_refill_rate
        }
    }
}
