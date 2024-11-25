#[starknet::interface]
pub trait IRateLimited<TState> {
    fn max_capacity(self: @TState) -> u256;
    fn calculate_current_level(self: @TState) -> u256;
    fn set_refill_rate(ref self: TState, capacity: u256) -> u256;
    fn validate_and_consume_filled_level(ref self: TState, consumed_amount: u256) -> u256;
    // getters 
    fn filled_level(self: @TState) -> u256;
    fn refill_rate(self: @TState) -> u256;
    fn last_updated(self: @TState) -> u64;
}

#[starknet::component]
pub mod RateLimitedComponent {
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalTrait as OwnableInternalTrait,
        interface::IOwnable
    };
    use starknet::ContractAddress;

    // A day
    pub const DURATION: u256 = 60 * 60 * 24;

    #[storage]
    pub struct Storage {
        filled_level: u256,
        refill_rate: u256,
        last_updated: u64
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RateLimitSet: RateLimitSet,
        ConsumedFilledLevel: ConsumedFilledLevel
    }

    #[derive(Drop, starknet::Event)]
    pub struct RateLimitSet {
        pub old_capacity: u256,
        pub new_capacity: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConsumedFilledLevel {
        pub filled_level: u256,
        pub last_updated: u64
    }

    #[embeddable_as(RateLimited)]
    pub impl RateLimitedImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IRateLimited<ComponentState<TContractState>> {
        /// Returns `u256` representing the max capacity where the bucket will no longer fill.
        fn max_capacity(self: @ComponentState<TContractState>) -> u256 {
            self.refill_rate.read() * DURATION
        }

        /// Calculates the adjsuted fill level based on time.
        /// 
        /// # Returns
        /// 
        /// A `u256` representing the current level.
        fn calculate_current_level(self: @ComponentState<TContractState>) -> u256 {
            let capacity = self.max_capacity();

            assert(capacity > 0, 'RateLimit not setted!');
            let current_timestamp = starknet::get_block_timestamp();
            let last_updated = self.last_updated.read();
            if current_timestamp > last_updated + DURATION.try_into().unwrap() {
                return capacity;
            }

            let replenished_level = self.filled_level.read() + self.calculate_refilled_amount();
            if replenished_level > capacity {
                capacity
            } else {
                replenished_level
            }
        }

        /// Sets the refill rate by given capacity.
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
            let old_refill_rate = self.refill_rate.read();
            let new_refill_rate = capacity / DURATION;
            self.refill_rate.write(new_refill_rate);
            self
                .emit(
                    RateLimitSet { old_capacity: old_refill_rate, new_capacity: new_refill_rate }
                );
            new_refill_rate
        }

        /// Validates the amount and decreases the current capacity.
        /// 
        /// # Arguments
        /// 
        /// - `consumed_amount` - A `u256` amount to consume the fill level.
        /// 
        /// # Returns
        /// 
        /// A `u256` representing the new filled level.
        fn validate_and_consume_filled_level(
            ref self: ComponentState<TContractState>, consumed_amount: u256
        ) -> u256 {
            let adjusted_filled_level = self.calculate_current_level();
            assert(consumed_amount <= adjusted_filled_level, 'RateLimitExceeded');

            let filled_level = adjusted_filled_level - consumed_amount;
            self.filled_level.write(filled_level);
            let last_updated = starknet::get_block_timestamp();
            self.last_updated.write(last_updated);
            self.emit(ConsumedFilledLevel { filled_level, last_updated });
            filled_level
        }

        /// Returns `u256` representing the filled_level.
        fn filled_level(self: @ComponentState<TContractState>) -> u256 {
            self.filled_level.read()
        }

        /// Returns `u256` representing the refill rate.
        fn refill_rate(self: @ComponentState<TContractState>) -> u256 {
            self.refill_rate.read()
        }

        /// Returns `u64` representing the last timestamp updated.
        fn last_updated(self: @ComponentState<TContractState>) -> u64 {
            self.last_updated.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initialize(
            ref self: ComponentState<TContractState>, capacity: u256, owner: ContractAddress
        ) { 
            let mut ownable_comp = get_dep_component_mut!(ref self, Ownable);
            ownable_comp.initializer(starknet::get_caller_address());

            assert(capacity >= DURATION, 'Capacity must gte to duration');
            self.set_refill_rate(capacity);
            self.filled_level.write(capacity);

            ownable_comp.transfer_ownership(owner);
        }

        /// Calculates the refilled amount based on time and refill rate.
        /// 
        /// To calculate:
        ///   refilled = elapsed * refilledRate
        ///   elapsed = timestamp - Limit.lastUpdated
        ///   RefilledRate = Capacity / DURATION
        /// 
        /// # Returns 
        /// 
        /// A `u256` representing the refilled amount.
        fn calculate_refilled_amount(self: @ComponentState<TContractState>) -> u256 {
            let elapsed = starknet::get_block_timestamp() - self.last_updated.read();
            elapsed.into() * self.refill_rate.read()
        }
    }
}
