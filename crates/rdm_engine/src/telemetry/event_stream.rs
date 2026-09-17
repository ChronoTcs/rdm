use crate::models::TelemetryEvent;
use tokio::sync::broadcast;

pub const TELEMETRY_CAPACITY: usize = 1024;

#[derive(Clone)]
pub struct TelemetryBroadcaster {
    sender: broadcast::Sender<TelemetryEvent>,
}

impl Default for TelemetryBroadcaster {
    fn default() -> Self {
        Self::new()
    }
}

impl TelemetryBroadcaster {
    pub fn new() -> Self {
        let (sender, _) = broadcast::channel(TELEMETRY_CAPACITY);
        Self { sender }
    }

    pub fn send(&self, event: TelemetryEvent) {
        let _ = self.sender.send(event);
    }

    pub fn subscribe(&self) -> broadcast::Receiver<TelemetryEvent> {
        self.sender.subscribe()
    }
}
