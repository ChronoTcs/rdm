use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TaskStatus {
    Queued,
    Downloading,
    Paused,
    Completed,
    Error,
    ExpiredLink,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TaskCategory {
    General,
    Compressed,
    Video,
    Audio,
    Documents,
    Programs,
}

impl TaskCategory {
    pub fn from_extension(input: &str) -> Self {
        let clean_ext = if let Some(dot_idx) = input.rfind('.') {
            &input[dot_idx + 1..]
        } else {
            input
        }
        .trim()
        .to_lowercase();

        match clean_ext.as_str() {
            "zip" | "rar" | "7z" | "tar" | "gz" | "bz2" | "xz" | "zst" | "iso" => TaskCategory::Compressed,
            "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "ts" | "m3u8" => TaskCategory::Video,
            "mp3" | "flac" | "wav" | "aac" | "ogg" | "m4a" => TaskCategory::Audio,
            "pdf" | "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "txt" | "epub" => TaskCategory::Documents,
            "exe" | "msi" | "dmg" | "pkg" | "deb" | "rpm" | "appimage" | "apk" => TaskCategory::Programs,
            _ => TaskCategory::General,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CookieDto {
    pub name: String,
    pub value: String,
    pub domain: String,
    pub path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskConfig {
    pub id: Option<String>,
    pub url: String,
    pub destination_path: String,
    pub filename: Option<String>,
    pub concurrency: u32,
    pub limit_bps: Option<u64>,
    pub headers: HashMap<String, String>,
    pub cookies: Vec<CookieDto>,
    pub category: Option<TaskCategory>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadTaskModel {
    pub id: String,
    pub url: String,
    pub filename: String,
    pub destination_path: String,
    pub total_bytes: u64,
    pub downloaded_bytes: u64,
    pub status: TaskStatus,
    pub speed_bps: u64,
    pub eta_seconds: u32,
    pub active_connections: u32,
    pub indeterminate: bool,
    pub category: TaskCategory,
    pub error_message: Option<String>,
    pub sha256_hash: Option<String>,
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SegmentProgress {
    pub connection_id: u32,
    pub start_offset: u64,
    pub current_offset: u64,
    pub end_offset: u64,
    pub speed_bps: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TelemetryEvent {
    Progress {
        task_id: String,
        downloaded_bytes: u64,
        total_bytes: u64,
        indeterminate: bool,
        speed_bps: u64,
        eta_seconds: u32,
        active_connections: u32,
        segments: Vec<SegmentProgress>,
    },
    StatusChanged {
        task_id: String,
        old_status: TaskStatus,
        new_status: TaskStatus,
        error_message: Option<String>,
    },
    UrlExpired {
        task_id: String,
        original_url: String,
        http_status: u16,
    },
    TaskCompleted {
        task_id: String,
        file_path: String,
        file_size: u64,
        sha256_hash: String,
    },
}
