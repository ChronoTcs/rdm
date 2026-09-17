use rdm_engine::coordinator::{get_instance, initialize, EngineCoordinator};
use rdm_engine::models::TaskConfig;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{self, Read, Write};
use std::sync::Arc;

#[derive(Deserialize)]
pub struct NativeMessage {
    pub action: String,
    pub url: Option<String>,
    pub filename: Option<String>,
    pub headers: Option<HashMap<String, String>>,
    pub task_id: Option<String>,
    pub new_url: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Eq)]
pub struct NativeResponse {
    pub status: String,
    pub task_id: Option<String>,
    pub message: Option<String>,
}

pub async fn handle_native_message(coord: &Arc<EngineCoordinator>, msg: NativeMessage) -> NativeResponse {
    match msg.action.as_str() {
        "download" => {
            if let Some(url) = msg.url {
                let config = TaskConfig {
                    id: msg.task_id,
                    url,
                    destination_path: ".".to_string(),
                    filename: msg.filename,
                    concurrency: 16,
                    limit_bps: None,
                    headers: msg.headers.unwrap_or_default(),
                    cookies: Vec::new(),
                    category: None,
                };

                match coord.add_task(config).await {
                    Ok(tid) => NativeResponse {
                        status: "ok".to_string(),
                        task_id: Some(tid),
                        message: Some("Download started".to_string()),
                    },
                    Err(e) => NativeResponse {
                        status: "error".to_string(),
                        task_id: None,
                        message: Some(e.to_string()),
                    },
                }
            } else {
                NativeResponse {
                    status: "error".to_string(),
                    task_id: None,
                    message: Some("Missing URL".to_string()),
                }
            }
        }
        "pause" => {
            if let Some(tid) = msg.task_id {
                match coord.pause_task(&tid).await {
                    Ok(()) => NativeResponse {
                        status: "ok".to_string(),
                        task_id: Some(tid),
                        message: Some("Task paused".to_string()),
                    },
                    Err(e) => NativeResponse {
                        status: "error".to_string(),
                        task_id: Some(tid),
                        message: Some(e.to_string()),
                    },
                }
            } else {
                NativeResponse {
                    status: "error".to_string(),
                    task_id: None,
                    message: Some("Missing task_id".to_string()),
                }
            }
        }
        "resume" => {
            if let Some(tid) = msg.task_id {
                match coord.resume_task(&tid).await {
                    Ok(()) => NativeResponse {
                        status: "ok".to_string(),
                        task_id: Some(tid),
                        message: Some("Task resumed".to_string()),
                    },
                    Err(e) => NativeResponse {
                        status: "error".to_string(),
                        task_id: Some(tid),
                        message: Some(e.to_string()),
                    },
                }
            } else {
                NativeResponse {
                    status: "error".to_string(),
                    task_id: None,
                    message: Some("Missing task_id".to_string()),
                }
            }
        }
        "cancel" => {
            if let Some(tid) = msg.task_id {
                match coord.cancel_task(&tid, false).await {
                    Ok(()) => NativeResponse {
                        status: "ok".to_string(),
                        task_id: Some(tid),
                        message: Some("Task cancelled".to_string()),
                    },
                    Err(e) => NativeResponse {
                        status: "error".to_string(),
                        task_id: Some(tid),
                        message: Some(e.to_string()),
                    },
                }
            } else {
                NativeResponse {
                    status: "error".to_string(),
                    task_id: None,
                    message: Some("Missing task_id".to_string()),
                }
            }
        }
        "refresh_url" => {
            if let (Some(tid), Some(new_url)) = (msg.task_id, msg.new_url) {
                match coord
                    .refresh_task_url(&tid, &new_url, msg.headers.unwrap_or_default(), Vec::new())
                    .await
                {
                    Ok(()) => NativeResponse {
                        status: "ok".to_string(),
                        task_id: Some(tid),
                        message: Some("Task URL refreshed".to_string()),
                    },
                    Err(e) => NativeResponse {
                        status: "error".to_string(),
                        task_id: Some(tid),
                        message: Some(e.to_string()),
                    },
                }
            } else {
                NativeResponse {
                    status: "error".to_string(),
                    task_id: None,
                    message: Some("Missing task_id or new_url".to_string()),
                }
            }
        }
        _ => NativeResponse {
            status: "error".to_string(),
            task_id: None,
            message: Some("Unknown action".to_string()),
        },
    }
}

fn main() -> io::Result<()> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(io::Error::other)?;
    let _guard = rt.enter();

    let _ = initialize("rdm_native.db".to_string(), 16);
    let coordinator = get_instance();

    let mut stdin = io::stdin();
    let mut stdout = io::stdout();

    let mut len_buf = [0u8; 4];
    while stdin.read_exact(&mut len_buf).is_ok() {
        let len = u32::from_ne_bytes(len_buf) as usize;
        if len == 0 || len > 10 * 1024 * 1024 {
            break;
        }

        let mut buf = vec![0u8; len];
        stdin.read_exact(&mut buf)?;

        if let Ok(msg) = serde_json::from_slice::<NativeMessage>(&buf) {
            let resp = rt.block_on(handle_native_message(&coordinator, msg));

            let out_bytes = serde_json::to_vec(&resp).unwrap();
            let out_len = (out_bytes.len() as u32).to_ne_bytes();
            stdout.write_all(&out_len)?;
            stdout.write_all(&out_bytes)?;
            stdout.flush()?;
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_native_message_unknown_action() {
        let coord = Arc::new(EngineCoordinator::new());
        let msg = NativeMessage {
            action: "invalid_action".to_string(),
            url: None,
            filename: None,
            headers: None,
            task_id: None,
            new_url: None,
        };

        let resp = handle_native_message(&coord, msg).await;
        assert_eq!(resp.status, "error");
        assert_eq!(resp.message, Some("Unknown action".to_string()));
    }

    #[tokio::test]
    async fn test_native_message_missing_url() {
        let coord = Arc::new(EngineCoordinator::new());
        let msg = NativeMessage {
            action: "download".to_string(),
            url: None,
            filename: None,
            headers: None,
            task_id: None,
            new_url: None,
        };

        let resp = handle_native_message(&coord, msg).await;
        assert_eq!(resp.status, "error");
        assert_eq!(resp.message, Some("Missing URL".to_string()));
    }

    #[tokio::test]
    async fn test_native_message_missing_task_id() {
        let coord = Arc::new(EngineCoordinator::new());
        let msg = NativeMessage {
            action: "pause".to_string(),
            url: None,
            filename: None,
            headers: None,
            task_id: None,
            new_url: None,
        };

        let resp = handle_native_message(&coord, msg).await;
        assert_eq!(resp.status, "error");
        assert_eq!(resp.message, Some("Missing task_id".to_string()));
    }
}
