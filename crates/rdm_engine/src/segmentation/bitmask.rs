use serde::{Deserialize, Serialize};

pub const BLOCK_SIZE: u64 = 256 * 1024; // 256 KB

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResumeBitmask {
    pub total_bytes: u64,
    pub block_size: u64,
    pub num_blocks: usize,
    bits: Vec<u8>,
}

impl ResumeBitmask {
    pub fn new(total_bytes: u64) -> Self {
        let block_size = BLOCK_SIZE;
        let num_blocks = if total_bytes == 0 {
            0
        } else {
            total_bytes.div_ceil(block_size) as usize
        };
        let num_bytes = num_blocks.div_ceil(8);
        Self {
            total_bytes,
            block_size,
            num_blocks,
            bits: vec![0u8; num_bytes],
        }
    }

    pub fn mark_block_downloaded(&mut self, block_idx: usize) {
        if block_idx < self.num_blocks {
            let byte_idx = block_idx / 8;
            let bit_idx = block_idx % 8;
            self.bits[byte_idx] |= 1 << bit_idx;
        }
    }

    pub fn is_block_downloaded(&self, block_idx: usize) -> bool {
        if block_idx < self.num_blocks {
            let byte_idx = block_idx / 8;
            let bit_idx = block_idx % 8;
            (self.bits[byte_idx] & (1 << bit_idx)) != 0
        } else {
            false
        }
    }

    pub fn mark_range_downloaded(&mut self, start: u64, end: u64) {
        if start > end || start >= self.total_bytes {
            return;
        }
        let clamped_end = end.min(self.total_bytes.saturating_sub(1));
        let start_block = (start / self.block_size) as usize;
        let end_block = (clamped_end / self.block_size) as usize;

        for b in start_block..=end_block {
            self.mark_block_downloaded(b);
        }
    }

    pub fn count_downloaded_blocks(&self) -> usize {
        let mut count = 0;
        for i in 0..self.num_blocks {
            if self.is_block_downloaded(i) {
                count += 1;
            }
        }
        count
    }

    pub fn is_complete(&self) -> bool {
        if self.num_blocks == 0 {
            return true;
        }
        self.count_downloaded_blocks() == self.num_blocks
    }

    pub fn total_downloaded_bytes(&self) -> u64 {
        let downloaded_blocks = self.count_downloaded_blocks();
        if downloaded_blocks == self.num_blocks {
            self.total_bytes
        } else {
            (downloaded_blocks as u64) * self.block_size
        }
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.bits
    }

    pub fn from_raw_parts(total_bytes: u64, bits: Vec<u8>) -> Self {
        let block_size = BLOCK_SIZE;
        let num_blocks = if total_bytes == 0 {
            0
        } else {
            total_bytes.div_ceil(block_size) as usize
        };
        Self {
            total_bytes,
            block_size,
            num_blocks,
            bits,
        }
    }

    pub fn get_missing_ranges(&self) -> Vec<crate::segmentation::dynamic_split::ByteRange> {
        use crate::segmentation::dynamic_split::ByteRange;
        if self.total_bytes == 0 || self.num_blocks == 0 {
            return Vec::new();
        }

        let mut ranges = Vec::new();
        let mut in_gap = false;
        let mut gap_start_block = 0;

        for b in 0..self.num_blocks {
            let downloaded = self.is_block_downloaded(b);
            if !downloaded && !in_gap {
                in_gap = true;
                gap_start_block = b;
            } else if downloaded && in_gap {
                in_gap = false;
                let start = (gap_start_block as u64) * self.block_size;
                let end = ((b as u64) * self.block_size - 1).min(self.total_bytes - 1);
                ranges.push(ByteRange::new(start, end));
            }
        }

        if in_gap {
            let start = (gap_start_block as u64) * self.block_size;
            let end = self.total_bytes - 1;
            ranges.push(ByteRange::new(start, end));
        }

        ranges
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bitmask_basic() {
        let total_bytes = 1024 * 1024; // 1 MB = 4 blocks of 256KB
        let mut mask = ResumeBitmask::new(total_bytes);
        assert_eq!(mask.num_blocks, 4);
        assert_eq!(mask.count_downloaded_blocks(), 0);
        assert!(!mask.is_complete());

        mask.mark_block_downloaded(0);
        assert!(mask.is_block_downloaded(0));
        assert!(!mask.is_block_downloaded(1));
        assert_eq!(mask.count_downloaded_blocks(), 1);

        mask.mark_range_downloaded(256 * 1024, 1024 * 1024 - 1);
        assert!(mask.is_complete());
        assert_eq!(mask.total_downloaded_bytes(), total_bytes);
    }

    #[test]
    fn test_bitmask_missing_ranges() {
        let total_bytes = 1024 * 1024; // 1 MB = 4 blocks of 256KB
        let mut mask = ResumeBitmask::new(total_bytes);
        // Initially all 4 blocks are missing -> 1 single range 0..1048575
        let missing = mask.get_missing_ranges();
        assert_eq!(missing.len(), 1);
        assert_eq!(missing[0].start, 0);
        assert_eq!(missing[0].end, 1024 * 1024 - 1);

        // Mark blocks 0 and 2 as downloaded
        mask.mark_block_downloaded(0);
        mask.mark_block_downloaded(2);
        // Missing blocks should be block 1 and block 3
        let missing2 = mask.get_missing_ranges();
        assert_eq!(missing2.len(), 2);
        assert_eq!(missing2[0].start, 256 * 1024);
        assert_eq!(missing2[0].end, 512 * 1024 - 1);
        assert_eq!(missing2[1].start, 768 * 1024);
        assert_eq!(missing2[1].end, 1024 * 1024 - 1);

        // Mark remaining blocks
        mask.mark_block_downloaded(1);
        mask.mark_block_downloaded(3);
        assert!(mask.get_missing_ranges().is_empty());
    }
}
