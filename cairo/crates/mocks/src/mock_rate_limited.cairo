#[starknet::contract]
mod MockRateLimited {
    use contracts::libs::rate_limited::RateLimitedComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnbaleInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: RateLimitedComponent, storage: rate_limited, event: RateLimitedEvent);

    #[abi(embed_v0)]
    impl RateLimitedImpl = RateLimitedComponent::RateLimited<ContractState>;
    impl RateLimitedInternalImpl = RateLimitedComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        rate_limited: RateLimitedComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RateLimitedEvent: RateLimitedComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, capacity: u256, owner: ContractAddress) {
        self.rate_limited.initialize(capacity, owner);
    }
}
