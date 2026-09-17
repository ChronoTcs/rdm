use std::collections::VecDeque;
use std::time::Instant;

pub struct SpeedCalculator {
    history: VecDeque<(Instant, u64)>, // (timestamp, total_bytes_downloaded)
    window_duration_secs: f64,
}

impl SpeedCalculator {
    pub fn new(window_duration_secs: f64) -> Self {
        Self {
            history: VecDeque::new(),
            window_duration_secs,
        }
    }

    pub fn record_progress(&mut self, current_total_bytes: u64) {
        let now = Instant::now();
        self.history.push_back((now, current_total_bytes));

        // Trim samples older than window_duration_secs
        while let Some((timestamp, _)) = self.history.front() {
            if now.duration_since(*timestamp).as_secs_f64() > self.window_duration_secs {
                self.history.pop_front();
            } else {
                break;
            }
        }
    }

    pub fn current_speed_bps(&self) -> u64 {
        if self.history.len() < 2 {
            return 0;
        }

        let (first_time, first_bytes) = self.history.front().unwrap();
        let (last_time, last_bytes) = self.history.back().unwrap();

        let elapsed = last_time.duration_since(*first_time).as_secs_f64();
        if elapsed <= 0.001 {
            return 0;
        }

        let delta_bytes = last_bytes.saturating_sub(*first_bytes);
        (delta_bytes as f64 / elapsed) as u64
    }

    pub fn calculate_eta(&self, remaining_bytes: u64) -> u32 {
        let speed = self.current_speed_bps();
        if speed == 0 {
            0
        } else {
            (remaining_bytes / speed).min(u32::MAX as u64) as u32
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_speed_calculator_basic() {
        let mut calc = SpeedCalculator::new(1.0);
        calc.record_progress(1_000_000);
        assert_eq!(calc.current_speed_bps(), 0);
    }
}
