use contracts::libs::rate_limited::{
    IRateLimitedDispatcher, IRateLimitedDispatcherTrait, IRateLimitedSafeDispatcher,
    IRateLimitedSafeDispatcherTrait, RateLimitedComponent,
};
use core::num::traits::Bounded;
use core::num::traits::One;
use core::ops::RemAssign;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_block_timestamp, cheat_caller_address, declare, spy_events,
    start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global,
};
use starknet::ContractAddress;

///************************************
///             Helpers
///************************************
pub const E18: u256 = 1_000_000_000_000_000_000;
pub const MAX_CAPACITY: u256 = E18;
pub const ONE_PERCENT: u256 = E18 / 100;
pub const DAY: u64 = 60 * 60 * 24;

/// see
/// {https://github.com/foundry-rs/foundry/blob/e16a75b615f812db6127ea22e23c3ee65504c1f1/crates/cheatcodes/src/test/assert.rs#L533}
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
            delta,
        );
    }
}

/// Bounds given value within given range [lower, upper]
pub fn bound<
    T,
    +PartialOrd<T>,
    +PartialEq<T>,
    +Bounded<T>,
    +Rem<T>,
    +Add<T>,
    +One<T>,
    +Drop<T>,
    +Copy<T>,
    // +RemAssign<T, T>,
    +RemAssign<T, T>,
>(
    mut value: T, lower: T, upper: T,
) -> T {
    if upper == Bounded::<T>::MAX {
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
    hook: ContractAddress,
}

fn setup() -> Setup {
    let rate_limited_contract = declare("MockRateLimited").unwrap().contract_class();
    let owner = starknet::contract_address_const::<'OWNER'>();
    let hook = starknet::contract_address_const::<'HOOK'>();
    let mut ctor_calldata: Array<felt252> = array![];
    MAX_CAPACITY.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    let (deployed_address, _) = rate_limited_contract.deploy(@ctor_calldata).unwrap();
    Setup {
        rate_limited: IRateLimitedDispatcher { contract_address: deployed_address }, owner, hook,
    }
}

///************************************
///             Tests
///************************************

#[test]
#[should_panic]
fn test_ctor_should_panic_when_low_capacity() {
    let rate_limited_contract = declare("MockRateLimited").unwrap().contract_class();
    let owner = starknet::contract_address_const::<'OWNER'>();
    let mut ctor_calldata: Array<felt252> = array![];
    (RateLimitedComponent::DURATION.into() - 1_u256).serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    rate_limited_contract.deploy(@ctor_calldata).unwrap();
}

#[test]
fn test_should_sets_new_limit() {
    let setup = setup();

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    assert!(setup.rate_limited.set_refill_rate(2 * E18) > 0);

    assert_approx_eq_rel(setup.rate_limited.max_capacity(), 2 * E18, ONE_PERCENT);
    assert!(setup.rate_limited.refill_rate() == 2 * E18 / DAY.into());
}

#[test]
#[should_panic(expected: 'RateLimit not set!')]
fn test_should_panic_when_max_not_set() {
    let setup = setup();

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    setup.rate_limited.set_refill_rate(0);
    setup.rate_limited.calculate_current_level();
}

#[test]
#[fuzzer]
fn test_should_return_curreny_filled_level_any_time(mut time: u64) {
    let setup = setup();
    time = bound(time, DAY, 2 * DAY);

    cheat_block_timestamp(setup.rate_limited.contract_address, time, CheatSpan::TargetCalls(1));
    let current_level = setup.rate_limited.calculate_current_level();

    assert_approx_eq_rel(current_level, MAX_CAPACITY, ONE_PERCENT);
}

#[test]
#[fuzzer]
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
    cheat_caller_address(
        setup.rate_limited.contract_address, caller_address, CheatSpan::TargetCalls(1),
    );
    setup.rate_limited.set_refill_rate(E18);
}

#[test]
fn test_should_consume_filled_level_and_emit_events() {
    let setup = setup();

    let consume_amount = E18 / 2;

    let mut spy = spy_events();

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );

    setup.rate_limited.validate_and_consume_filled_level(consume_amount);

    assert_approx_eq_rel(
        setup.rate_limited.filled_level(), MAX_CAPACITY - consume_amount, 100_000_000_000_000,
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
                            filled_level: 499999999999993600, last_updated: current_timestamp,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[fuzzer]
fn test_should_never_return_gt_max_limit(mut new_amount: u256, mut new_time: u64) {
    let setup = setup();

    new_time = bound(new_time, 0, Bounded::MAX - DAY);
    start_cheat_block_timestamp_global(new_time);

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    let current_level = setup.rate_limited.calculate_current_level();
    new_amount = bound(new_amount, 0, current_level);
    setup.rate_limited.validate_and_consume_filled_level(new_amount);

    let new_current_level = setup.rate_limited.calculate_current_level();
    assert!(new_current_level <= setup.rate_limited.max_capacity());
    stop_cheat_block_timestamp_global();
}

#[test]
#[feature("safe_dispatcher")]
fn test_should_decreases_limit_within_same_day() {
    let setup = setup();

    cheat_block_timestamp(setup.rate_limited.contract_address, DAY, CheatSpan::TargetCalls(1));
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    let amount = 4 * E18 / 10;

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert!(new_limit == current_target_limit - amount);
    // consume the same amount
    current_target_limit = setup.rate_limited.calculate_current_level();
    new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert!(new_limit == current_target_limit - amount);
    // one more to exceed limit
    let new_current_level = setup.rate_limited.calculate_current_level();
    assert!(new_current_level <= setup.rate_limited.max_capacity());
    let safe_dispatcher = IRateLimitedSafeDispatcher {
        contract_address: setup.rate_limited.contract_address,
    };

    match safe_dispatcher.validate_and_consume_filled_level(amount) {
        Result::Ok(_) => panic!("should have been panicked!"),
        Result::Err(data) => { assert!(*data.at(0) == 'RateLimit exceeded'); },
    }
}

#[test]
fn test_replenishes_within_same_day() {
    let setup = setup();

    let amount = 95 * E18 / 100;
    start_cheat_block_timestamp_global(DAY);
    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    assert_approx_eq_rel(current_target_limit, E18 / 20, ONE_PERCENT);

    start_cheat_block_timestamp_global(
        starknet::get_block_timestamp() + (99 * DAY / 100).try_into().unwrap(),
    );
    new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert_approx_eq_rel(new_limit, E18 / 20, ONE_PERCENT);

    stop_cheat_block_timestamp_global();
}

#[test]
#[fuzzer]
fn test_should_reset_limit_when_duration_exceeds(mut amount: u256) {
    let setup = setup();

    start_cheat_block_timestamp_global(DAY / 2);
    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    amount = bound(amount, 0, current_target_limit - 1);
    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    let mut new_limit = setup.rate_limited.validate_and_consume_filled_level(amount);
    assert_approx_eq_rel(new_limit, current_target_limit - amount, ONE_PERCENT);

    start_cheat_block_timestamp_global(10 * DAY);

    let mut current_target_limit = setup.rate_limited.calculate_current_level();
    assert_approx_eq_rel(current_target_limit, MAX_CAPACITY, ONE_PERCENT);

    stop_cheat_block_timestamp_global();
}

#[test]
#[should_panic(expected: 'RateLimit not set!')]
fn test_should_panic_when_current_level_when_capacity_is_zero() {
    let setup = setup();

    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    setup.rate_limited.set_refill_rate(0);

    setup.rate_limited.calculate_current_level();
}

#[test]
#[should_panic(expected: 'RateLimit exceeded')]
fn test_should_panic_when_validate_consume_filled_levels_when_exceeding_limit() {
    let setup = setup();

    start_cheat_block_timestamp_global(DAY);
    let mut initial_level = setup.rate_limited.calculate_current_level();
    let excess_amount = initial_level + E18;
    cheat_caller_address(
        setup.rate_limited.contract_address, setup.owner, CheatSpan::TargetCalls(1),
    );
    setup.rate_limited.validate_and_consume_filled_level(excess_amount);
    stop_cheat_block_timestamp_global();
}
