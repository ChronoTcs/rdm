use proptest::prelude::*;
use rdm_engine::{bisect_interval, MIN_SPLIT_SIZE};

proptest! {
    #[test]
    fn test_dynamic_bisection_invariants(
        cursor in 0u64..1_000_000,
        gap in (2 * MIN_SPLIT_SIZE)..10_000_000
    ) {
        let end = cursor + gap;
        let remaining = end - cursor + 1;

        let result = bisect_interval(cursor, end);
        prop_assert!(result.is_some());

        let (truncated_range, stolen_range) = result.unwrap();

        // Invariant 1: Start boundary must equal cursor
        prop_assert_eq!(truncated_range.start, cursor);

        // Invariant 2: Ranges must be strictly contiguous and non-overlapping
        prop_assert_eq!(truncated_range.end + 1, stolen_range.start);

        // Invariant 3: End boundary of stolen range must equal original end
        prop_assert_eq!(stolen_range.end, end);

        // Invariant 4: Sum of lengths must exactly equal original remaining bytes
        prop_assert_eq!(truncated_range.len() + stolen_range.len(), remaining);
    }

    #[test]
    fn test_dynamic_bisection_small_interval(
        cursor in 0u64..1_000_000,
        gap in 0u64..(2 * MIN_SPLIT_SIZE - 2)
    ) {
        let end = cursor + gap;
        let result = bisect_interval(cursor, end);
        prop_assert_eq!(result, None);
    }
}
