use super::dynamic_split::{bisect_interval, ByteRange, MIN_SPLIT_SIZE};
use crate::models::SegmentProgress;
use parking_lot::RwLock;

pub const VARIANCE_THRESHOLD: f64 = 0.40;

#[derive(Debug, Clone)]
pub struct ActiveWorker {
    pub connection_id: u32,
    pub start_offset: u64,
    pub current_offset: u64,
    pub end_offset: u64,
    pub speed_bps: u64,
    pub is_active: bool,
}

impl ActiveWorker {
    pub fn remaining_bytes(&self) -> u64 {
        if self.end_offset >= self.current_offset {
            self.end_offset - self.current_offset + 1
        } else {
            0
        }
    }

    pub fn to_progress(&self) -> SegmentProgress {
        SegmentProgress {
            connection_id: self.connection_id,
            start_offset: self.start_offset,
            current_offset: self.current_offset,
            end_offset: self.end_offset,
            speed_bps: self.speed_bps,
        }
    }
}

pub struct SegmentManager {
    pub total_bytes: u64,
    pub max_connections: u32,
    workers: RwLock<Vec<ActiveWorker>>,
}

impl SegmentManager {
    pub fn new(total_bytes: u64, max_connections: u32) -> Self {
        Self {
            total_bytes,
            max_connections,
            workers: RwLock::new(Vec::new()),
        }
    }

    /// Initializes starting segments evenly across initial connection count
    pub fn initialize_segments(&self, initial_connections: u32) {
        let mut workers = self.workers.write();
        workers.clear();

        if self.total_bytes == 0 || initial_connections == 0 {
            return;
        }

        let chunk_size = self.total_bytes / (initial_connections as u64);
        let mut current_start = 0;

        for i in 0..initial_connections {
            let current_end = if i == initial_connections - 1 {
                self.total_bytes - 1
            } else {
                current_start + chunk_size - 1
            };

            workers.push(ActiveWorker {
                connection_id: i + 1,
                start_offset: current_start,
                current_offset: current_start,
                end_offset: current_end,
                speed_bps: 0,
                is_active: true,
            });

            current_start = current_end + 1;
        }
    }

    pub fn update_worker_progress(&self, connection_id: u32, bytes_written: u64, speed_bps: u64) {
        let mut workers = self.workers.write();
        if let Some(w) = workers.iter_mut().find(|w| w.connection_id == connection_id) {
            w.current_offset = (w.current_offset + bytes_written).min(w.end_offset + 1);
            w.speed_bps = speed_bps;
            if w.current_offset > w.end_offset {
                w.is_active = false;
            }
        }
    }

    /// Checks if work-stealing bisection should occur.
    /// Returns Some((target_connection_id, stolen_range)) if a candidate segment was bisected.
    pub fn try_work_steal_rebalance(&self) -> Option<(u32, ByteRange)> {
        let mut workers = self.workers.write();

        // 1. Find candidate interval with maximum remaining bytes >= 2 * MIN_SPLIT_SIZE
        let mut best_candidate_idx = None;
        let mut max_remaining = 0;

        for (idx, w) in workers.iter().enumerate() {
            if w.is_active {
                let remaining = w.remaining_bytes();
                if remaining >= 2 * MIN_SPLIT_SIZE && remaining > max_remaining {
                    max_remaining = remaining;
                    best_candidate_idx = Some(idx);
                }
            }
        }

        let candidate_idx = best_candidate_idx?;

        // Check if there is an idle worker slot or speed variance threshold is met
        let active_count = workers.iter().filter(|w| w.is_active).count() as u32;
        let has_capacity = active_count < self.max_connections;

        let should_split = if has_capacity {
            true
        } else {
            // Check speed variance
            let speeds: Vec<u64> = workers.iter().filter(|w| w.is_active).map(|w| w.speed_bps).collect();
            if speeds.len() >= 2 {
                let max_speed = *speeds.iter().max().unwrap_or(&0) as f64;
                let min_speed = *speeds.iter().min().unwrap_or(&0) as f64;
                max_speed > 0.0 && ((max_speed - min_speed) / max_speed) > VARIANCE_THRESHOLD
            } else {
                false
            }
        };

        if !should_split {
            return None;
        }

        let candidate = &workers[candidate_idx];
        if let Some((truncated, stolen)) = bisect_interval(candidate.current_offset, candidate.end_offset) {
            let next_conn_id = workers.iter().map(|w| w.connection_id).max().unwrap_or(0) + 1;
            // Update candidate's end_offset to truncated.end
            workers[candidate_idx].end_offset = truncated.end;

            // Spawn new worker for stolen range
            workers.push(ActiveWorker {
                connection_id: next_conn_id,
                start_offset: stolen.start,
                current_offset: stolen.start,
                end_offset: stolen.end,
                speed_bps: 0,
                is_active: true,
            });

            return Some((next_conn_id, stolen));
        }

        None
    }

    pub fn get_worker_end_offset(&self, connection_id: u32) -> Option<u64> {
        let workers = self.workers.read();
        workers
            .iter()
            .find(|w| w.connection_id == connection_id)
            .map(|w| w.end_offset)
    }

    pub fn mark_worker_inactive(&self, connection_id: u32) {
        let mut workers = self.workers.write();
        if let Some(w) = workers.iter_mut().find(|w| w.connection_id == connection_id) {
            w.is_active = false;
            w.speed_bps = 0;
        }
    }

    pub fn get_active_workers_for_resume(&self) -> Vec<ActiveWorker> {
        let mut workers = self.workers.write();
        for w in workers.iter_mut() {
            if w.current_offset <= w.end_offset {
                w.is_active = true;
            }
        }
        workers
            .iter()
            .filter(|w| w.current_offset <= w.end_offset)
            .cloned()
            .collect()
    }

    pub fn initialize_from_ranges(&self, ranges: &[ByteRange]) {
        let mut workers = self.workers.write();
        workers.clear();
        for (i, r) in ranges.iter().enumerate() {
            workers.push(ActiveWorker {
                connection_id: (i + 1) as u32,
                start_offset: r.start,
                current_offset: r.start,
                end_offset: r.end,
                speed_bps: 0,
                is_active: true,
            });
        }
    }

    pub fn get_segment_telemetry(&self) -> Vec<SegmentProgress> {
        let workers = self.workers.read();
        workers.iter().map(|w| w.to_progress()).collect()
    }

    pub fn total_downloaded(&self) -> u64 {
        let workers = self.workers.read();
        workers.iter().map(|w| w.current_offset.saturating_sub(w.start_offset)).sum()
    }

    pub fn is_all_complete(&self) -> bool {
        let workers = self.workers.read();
        if workers.is_empty() {
            return false;
        }
        workers.iter().all(|w| w.current_offset > w.end_offset)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_segment_manager_initialization() {
        let total_bytes = 10 * 1024 * 1024; // 10 MB
        let mgr = SegmentManager::new(total_bytes, 4);
        mgr.initialize_segments(4);

        let telemetry = mgr.get_segment_telemetry();
        assert_eq!(telemetry.len(), 4);
        assert_eq!(telemetry[0].start_offset, 0);
        assert_eq!(telemetry[3].end_offset, total_bytes - 1);
    }

    #[test]
    fn test_segment_manager_work_stealing() {
        let total_bytes = 10 * 1024 * 1024; // 10 MB
        let mgr = SegmentManager::new(total_bytes, 8);
        mgr.initialize_segments(2); // Starts with 2 connections

        // Try rebalance: capacity exists (2 < 8) and remaining > 2 * MIN_SPLIT_SIZE
        let rebalance = mgr.try_work_steal_rebalance();
        assert!(rebalance.is_some());
        let (new_conn_id, stolen) = rebalance.unwrap();
        assert_eq!(new_conn_id, 3);
        assert!(stolen.len() > 0);

        let telemetry = mgr.get_segment_telemetry();
        assert_eq!(telemetry.len(), 3);
    }

    #[test]
    fn test_segment_manager_resume_filtering() {
        let total_bytes = 10 * 1024 * 1024;
        let mgr = SegmentManager::new(total_bytes, 2);
        mgr.initialize_segments(2);

        // Complete first segment:
        // segment 1: 0..4999999
        // segment 2: 5000000..9999999
        let end1 = mgr.get_worker_end_offset(1).unwrap();
        mgr.update_worker_progress(1, end1 + 1, 1000);
        assert_eq!(mgr.get_worker_end_offset(1), Some(end1));

        let active = mgr.get_active_workers_for_resume();
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].connection_id, 2);
    }
}
