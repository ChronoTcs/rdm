use thiserror::Error;

#[derive(Error, Debug)]
pub enum EngineError {
    #[error("Task not found: {0}")]
    TaskNotFound(String),

    #[error("Network error: {0}")]
    Network(String),

    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Target filesystem is FAT32 which cannot support files >= 4 GB ({0} bytes)")]
    Fat32BarrierExceeded(u64),

    #[error("URL expired with HTTP status {0}")]
    UrlExpired(u16),

    #[error("Incompatible resource length during URL refresh: expected {expected}, got {actual}")]
    IncompatibleResourceLength { expected: u64, actual: u64 },

    #[error("Internal engine error: {0}")]
    Internal(String),
}

pub type Result<T> = std::result::Result<T, EngineError>;
