use core::num::traits::{Bounded, One};
use core::ops::RemAssign;

pub const HOUR: u64 = 60 * 60;
pub const DAY: u64 = HOUR * 24;
pub const E18: u256 = 1_000_000_000_000_000_000;
pub const E40: u256 = 10_000_000_000_000_000_000_000_000_000_000_000_000_000;
pub const U256MAX_DIV_2: u256 = core::num::traits::Bounded::MAX / 2;

/// Bounds given value within given range [lower, upper]
pub fn bound<
    T,
    +PartialOrd<T>,
    +PartialEq<T>,
    +Bounded<T>,
    +RemAssign<T, T>,
    +Add<T>,
    +One<T>,
    +Drop<T>,
    +Copy<T>,
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

/// see
/// {https://github.com/foundry-rs/foundry/blob/e16a75b615f812db6127ea22e23c3ee65504c1f1/crates/cheatcodes/src/test/assert.rs#L533}
pub fn assert_approx_eq_rel(lhs: u256, rhs: u256, max_delta: u256) {
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
