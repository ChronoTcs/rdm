use parking_lot::Mutex;
use std::sync::Arc;
use std::time::Instant;
use tokio::time::{sleep, Duration};

#[derive(Debug)]
pub struct TokenBucket {
    rate_bps: Mutex<Option<u64>>,
    available_tokens: Mutex<f64>,
    last_replenished: Mutex<Instant>,
}

impl TokenBucket {
    pub fn new(rate_bps: Option<u64>) -> Self {
        Self {
            rate_bps: Mutex::new(rate_bps),
            available_tokens: Mutex::new(rate_bps.unwrap_or(0) as f64),
            last_replenished: Mutex::new(Instant::now()),
        }
    }

    pub fn set_rate(&self, rate_bps: Option<u64>) {
        let mut rate = self.rate_bps.lock();
        *rate = rate_bps;
        let mut tokens = self.available_tokens.lock();
        if let Some(r) = rate_bps {
            *tokens = (*tokens).min(r as f64);
        }
    }

    pub fn get_rate(&self) -> Option<u64> {
        *self.rate_bps.lock()
    }

    pub fn replenish(&self) {
        let rate_opt = *self.rate_bps.lock();
        let Some(rate_bps) = rate_opt else {
            return;
        };

        let mut last = self.last_replenished.lock();
        let now = Instant::now();
        let elapsed = now.duration_since(*last).as_secs_f64();
        *last = now;

        let mut tokens = self.available_tokens.lock();
        let max_capacity = rate_bps as f64; // 1 second burst capacity
        *tokens = (*tokens + elapsed * rate_bps as f64).min(max_capacity);
    }

    /// Acquires tokens for `needed` bytes.
    /// If throttled, sleeps until tokens become available.
    pub async fn acquire(&self, mut needed: usize) -> usize {
        let total_needed = needed;
        let rate_opt = *self.rate_bps.lock();
        if rate_opt.is_none() {
            return total_needed;
        }
        let rate_bps = rate_opt.unwrap();
        if rate_bps == 0 {
            // Rate limit 0 means fully paused / stalled
            sleep(Duration::from_millis(50)).await;
            return 0;
        }

        while needed > 0 {
            self.replenish();

            let taken = {
                let mut tokens = self.available_tokens.lock();
                if *tokens >= 1.0 {
                    let to_take = (*tokens).min(needed as f64);
                    *tokens -= to_take;
                    to_take as usize
                } else {
                    0
                }
            };

            if taken > 0 {
                needed -= taken;
            }

            if needed > 0 {
                let tokens = *self.available_tokens.lock();
                let deficit = (needed as f64 - tokens).max(1.0);
                let wait_secs = deficit / rate_bps as f64;
                sleep(Duration::from_secs_f64(wait_secs.clamp(0.001, 0.25))).await;
            }
        }

        total_needed
    }
}

pub struct HierarchicalBandwidthLimiter {
    global_bucket: Arc<TokenBucket>,
}

impl HierarchicalBandwidthLimiter {
    pub fn new(global_rate_bps: Option<u64>) -> Self {
        Self {
            global_bucket: Arc::new(TokenBucket::new(global_rate_bps)),
        }
    }

    pub fn set_global_rate(&self, rate_bps: Option<u64>) {
        self.global_bucket.set_rate(rate_bps);
    }

    pub fn global_bucket(&self) -> Arc<TokenBucket> {
        self.global_bucket.clone()
    }

    pub async fn acquire_bandwidth(
        &self,
        task_bucket: Option<&TokenBucket>,
        requested_bytes: usize,
    ) -> usize {
        // 1. Task Tier
        if let Some(tb) = task_bucket {
            let _ = tb.acquire(requested_bytes).await;
        }

        // 2. Global Tier
        let _ = self.global_bucket.acquire(requested_bytes).await;
        requested_bytes
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_unlimited_bucket() {
        let bucket = TokenBucket::new(None);
        let acquired = bucket.acquire(64 * 1024).await;
        assert_eq!(acquired, 64 * 1024);
    }

    #[tokio::test]
    async fn test_limited_bucket() {
        let bucket = TokenBucket::new(Some(100_000)); // 100 KB/s
        let acquired = bucket.acquire(10_000).await;
        assert_eq!(acquired, 10_000);
    }
}
