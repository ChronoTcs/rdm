use serde::{Deserialize, Serialize};

pub const MIN_SPLIT_SIZE: u64 = 512 * 1024; // 512 KB

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct ByteRange {
    pub start: u64,
    pub end: u64,
}

impl ByteRange {
    pub fn new(start: u64, end: u64) -> Self {
        Self { start, end }
    }

    pub fn len(&self) -> u64 {
        if self.end >= self.start {
            self.end - self.start + 1
        } else {
            0
        }
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Bisects an active range `[cursor, end]` in half if remaining bytes >= 2 * MIN_SPLIT_SIZE.
/// Returns (truncated_range, stolen_range) where:
/// - truncated_range = [cursor, midpoint]
/// - stolen_range = [midpoint + 1, end]
pub fn bisect_interval(cursor: u64, end: u64) -> Option<(ByteRange, ByteRange)> {
    if cursor > end {
        return None;
    }

    let remaining = end - cursor + 1;
    if remaining < 2 * MIN_SPLIT_SIZE {
        return None;
    }

    // Midpoint: cursor + floor((end - cursor) / 2)
    let midpoint = cursor + (end - cursor) / 2;

    // Guard against edge cases where midpoint == end
    if midpoint >= end {
        return None;
    }

    let truncated = ByteRange::new(cursor, midpoint);
    let stolen = ByteRange::new(midpoint + 1, end);

    Some((truncated, stolen))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bisect_minimum_threshold() {
        // Less than 2 * MIN_SPLIT_SIZE (1 MB) should return None
        let cursor = 0;
        let end = (2 * MIN_SPLIT_SIZE) - 2; // remaining = 1024 * 1024 - 1
        assert_eq!(bisect_interval(cursor, end), None);
    }

    #[test]
    fn test_bisect_exact_split() {
        let cursor = 0;
        let end = (2 * MIN_SPLIT_SIZE) - 1; // exactly 1MB (1,048,576 bytes)
        let res = bisect_interval(cursor, end);
        assert!(res.is_some());
        let (truncated, stolen) = res.unwrap();
        assert_eq!(truncated.start, 0);
        assert_eq!(truncated.end, 524_287);
        assert_eq!(stolen.start, 524_288);
        assert_eq!(stolen.end, end);

        // Verify union equals original length
        assert_eq!(truncated.len() + stolen.len(), end - cursor + 1);
    }

    #[test]
    fn test_bisect_with_nonzero_cursor() {
        let cursor = 10_000_000;
        let end = cursor + 10_000_000 - 1;
        let (truncated, stolen) = bisect_interval(cursor, end).unwrap();

        assert_eq!(truncated.start, cursor);
        assert_eq!(truncated.end + 1, stolen.start);
        assert_eq!(stolen.end, end);
        assert_eq!(truncated.len() + stolen.len(), 10_000_000);
    }
}
