use contracts::libs::rate_limited::{
    RateLimitedComponent, IRateLimitedDispatcher, IRateLimitedDispatcherTrait,
    IRateLimitedSafeDispatcher, IRateLimitedSafeDispatcherTrait,
    RateLimitedComponent::InternalTrait as RateLimitedInternalTrait
};
use core::integer::BoundedInt;
use core::num::traits::{Zero, One};
use snforge_std::{
    declare, ContractClassTrait, start_prank, CheatTarget, stop_prank, start_warp, stop_warp,
    spy_events, EventAssertions, SpyOn
};
use starknet::ContractAddress;

///************************************
///             Helpers
///************************************
pub const E18: u256 = 1_000_000_000_000_000_000;
pub const MAX_CAPACITY: u256 = E18;
pub const ONE_PERCENT: u256 = E18 / 100;
pub const DAY: u64 = 60 * 60 * 24;

/// see {https://github.com/foundry-rs/foundry/blob/e16a75b615f812db6127ea22e23c3ee65504c1f1/crates/cheatcodes/src/test/assert.rs#L533}
fn assert_approx_eq_rel(lhs: u256, rhs: u256, max_delta: u256) {
    if lhs == 0 {
        if rhs == 0 {
            return;
        } else {
            panic!("eq_rel_assertion error lhs {}, rhs {}, max_delta {}", lhs, rhs, max_delta);
        }
    }

    let mut delta = if lhs > rhs {
        lhs - rhs
    } else {
        rhs - lhs
    };

    delta *= E18;
    delta /= rhs;

    if delta > max_delta {
        panic!(
            "eq_rel_assertion error lhs {}, rhs {}, max_delta {}, real_delta {}",
            lhs,
            rhs,
            max_delta,
            delta
        );
    }
}

/// Bounds given value within given range [lower, upper]
pub fn bound<
    T,
    +PartialOrd<T>,
    +PartialEq<T>,
    +BoundedInt<T>,
    +RemEq<T>,
    +Add<T>,
    +One<T>,
    +Drop<T>,
    +Copy<T>
>(
    mut value: T, lower: T, upper: T
) -> T {
    if upper == BoundedInt::<T>::max() {
        if value < lower {
            return lower;
        }
        return value;
    }

    value %= upper + One::<T>::one();
    if value < lower {
        return lower;
    }
    value
}

///************************************
///             Setup
///************************************
#[derive(Drop)]
struct Setup {
    rate_limited: IRateLimitedDispatcher,
    owner: ContractAddress,
    hook: ContractAddress
}

fn setup() -> Setup {
    let rate_limited_contract = declare("MockRateLimited").unwrap();
    let owner = starknet::contract_address_const::<'OWNER'>();
    let hook = starknet::contract_address_const::<'HOOK'>();
    let mut ctor_calldata: Array<felt252> = array![];
    MAX_CAPACITY.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    let (deployed_address, _) = rate_limited_contract.deploy(@ctor_calldata).unwrap();
    Setup {
        rate_limited: IRateLimitedDispatcher { contract_address: deployed_address }, owner, hook
    }
}

///************************************
///             Tests
///************************************

#[test]
#[should_panic]
fn test_ctor_should_panic_when_low_capacity() {
    let rate_limited_contract = declare("MockRateLimited").unwrap();
    let owner = starknet::contract_address_const::<'OWNER'>();
    let mut ctor_calldata: Array<felt252> = array![];
    (RateLimitedComponent::DURATION.into() - 1_u256).serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    rate_limited_contract.deploy(@ctor_calldata).unwrap();
}

#[test]
fn test_should_sets_new_limit() {
    let setup = setup();

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    assert!(setup.rate_limited.set_refill_rate(2 * E18) > 0);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));

    assert_approx_eq_rel(setup.rate_limited.max_capacity(), 2 * E18, ONE_PERCENT);
    assert!(setup.rate_limited.refill_rate() == 2 * E18 / DAY.into());
}

#[test]
#[should_panic(expected: 'RateLimit not set!')]
fn test_should_panic_when_max_not_set() {
    let setup = setup();

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    setup.rate_limited.set_refill_rate(0);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));

    setup.rate_limited.calculate_current_level();
}

#[test]
fn test_should_return_curreny_filled_level_any_time(mut time: u64) {
    let setup = setup();
    time = bound(time, DAY, 2 * DAY);

    start_warp(CheatTarget::One(setup.rate_limited.contract_address), time);
    let current_level = setup.rate_limited.calculate_current_level();
    stop_warp(CheatTarget::One(setup.rate_limited.contract_address));

    assert_approx_eq_rel(current_level, MAX_CAPACITY, ONE_PERCENT);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_should_panic_when_caller_not_owner_when_set_limits(mut caller_u128: u128) {
    let setup = setup();

    let mut caller_felt: felt252 = caller_u128.into();

    if caller_felt == 0 {
        caller_felt += 1;
    }

    let mut caller_address: ContractAddress = caller_felt.try_into().unwrap();

    if caller_address == setup.owner {
        caller_address = (caller_felt + 1).try_into().unwrap();
    }

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), caller_address);
    setup.rate_limited.set_refill_rate(E18);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));
}

#[test]
fn test_should_consume_filled_level_and_emit_events() {
    let setup = setup();

    let consume_amount = E18 / 2;

    let mut spy = spy_events(SpyOn::One(setup.rate_limited.contract_address));

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    setup.rate_limited.validate_and_consume_filled_level(consume_amount);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));

    assert_approx_eq_rel(
        setup.rate_limited.filled_level(), MAX_CAPACITY - consume_amount, 100_000_000_000_000
    );

    let current_timestamp = starknet::get_block_timestamp();
    assert!(setup.rate_limited.last_updated() == current_timestamp);
    spy
        .assert_emitted(
            @array![
                (
                    setup.rate_limited.contract_address,
                    RateLimitedComponent::Event::ConsumedFilledLevel(
                        RateLimitedComponent::ConsumedFilledLevel {
                            filled_level: 499999999999993600, last_updated: current_timestamp
                        }
                    )
                )
            ]
        );
}

#[test]
fn test_should_never_return_gt_max_limit(mut new_amount: u256, mut new_time: u64) {
    let setup = setup();

    new_time = bound(new_time, 0, BoundedInt::max() - DAY);
    start_warp(CheatTarget::All, new_time);
    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    let current_level = setup.rate_limited.calculate_current_level();
    new_amount = bound(new_amount, 0, current_level);
    setup.rate_limited.validate_and_consume_filled_level(new_amount);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));

    let new_current_level = setup.rate_limited.calculate_current_level();
    assert!(new_current_level <= setup.rate_limited.max_capacity());
    stop_warp(CheatTarget::All);
}

#[test]
#[feature("safe_dispatcher")]
fn test_should_decreases_limit_within_same_day() {
    let setup = setup();

    start_warp(CheatTarget::One(setup.rate_limited.contract_address), DAY);
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    let amount = 4 * E18 / 10;

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert!(new_limit == current_target_limit - amount);
    // consume the same amount
    current_target_limit = setup.rate_limited.calculate_current_level();
    new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert!(new_limit == current_target_limit - amount);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));
    // one more to exceed limit
    let new_current_level = setup.rate_limited.calculate_current_level();
    assert!(new_current_level <= setup.rate_limited.max_capacity());
    let safe_dispatcher = IRateLimitedSafeDispatcher {
        contract_address: setup.rate_limited.contract_address
    };

    match safe_dispatcher.validate_and_consume_filled_level(amount) {
        Result::Ok(_) => panic!("should have been panicked!"),
        Result::Err(data) => { assert!(*data.at(0) == 'RateLimit exceeded'); },
    }

    stop_warp(CheatTarget::One(setup.rate_limited.contract_address));
}

#[test]
fn test_replenishes_within_same_day() {
    let setup = setup();

    let amount = 95 * E18 / 100;
    start_warp(CheatTarget::All, DAY);
    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    assert_approx_eq_rel(current_target_limit, E18 / 20, ONE_PERCENT);

    start_warp(
        CheatTarget::All, starknet::get_block_timestamp() + (99 * DAY / 100).try_into().unwrap()
    );
    new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert_approx_eq_rel(new_limit, E18 / 20, ONE_PERCENT);

    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));
    stop_warp(CheatTarget::All);
}

#[test]
fn test_should_reset_limit_when_duration_exceeds(mut amount: u256) {
    let setup = setup();

    start_warp(CheatTarget::All, DAY / 2);
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    amount = bound(amount, 0, current_target_limit - 1);
    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert_approx_eq_rel(new_limit, current_target_limit - amount, ONE_PERCENT);

    start_warp(CheatTarget::All, 10 * DAY);

    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    assert_approx_eq_rel(current_target_limit, MAX_CAPACITY, ONE_PERCENT);

    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));
    stop_warp(CheatTarget::All);
}

#[test]
#[should_panic(expected: 'RateLimit not set!')]
fn test_should_panic_when_current_level_when_capacity_is_zero() {
    let setup = setup();

    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    setup.rate_limited.set_refill_rate(0);
    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));

    setup.rate_limited.calculate_current_level();
}

#[test]
#[should_panic(expected: 'RateLimit exceeded')]
fn test_should_panic_when_validate_consume_filled_levels_when_exceeding_limit() {
    let setup = setup();

    start_warp(CheatTarget::All, DAY);
    let mut initial_level = setup.rate_limited.calculate_current_level();
    let excess_amount = initial_level + E18;
    start_prank(CheatTarget::One(setup.rate_limited.contract_address), setup.owner);
    setup.rate_limited.validate_and_consume_filled_level(excess_amount);

    stop_prank(CheatTarget::One(setup.rate_limited.contract_address));
    stop_warp(CheatTarget::All);
}
