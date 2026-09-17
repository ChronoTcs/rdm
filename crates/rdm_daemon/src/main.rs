use rdm_engine::coordinator::{get_instance, initialize, EngineCoordinator};
use rdm_engine::models::TaskConfig;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

#[derive(Deserialize)]
pub struct RpcRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: Option<serde_json::Value>,
    pub id: u64,
}

#[derive(Serialize, Deserialize)]
pub struct RpcResponse<T> {
    pub jsonrpc: String,
    pub result: Option<T>,
    pub error: Option<String>,
    pub id: u64,
}

pub async fn handle_rpc_request(coord: &Arc<EngineCoordinator>, req: RpcRequest) -> String {
    match req.method.as_str() {
        "rdm.getAllTasks" | "download.list" => {
            let tasks = coord.get_all_tasks().await.unwrap_or_default();
            serde_json::to_string(&RpcResponse {
                jsonrpc: "2.0".to_string(),
                result: Some(tasks),
                error: None,
                id: req.id,
            })
            .unwrap()
        }
        "rdm.addDownload" | "download.add" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let url = params
                .get("url")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();

            if url.is_empty() {
                return serde_json::to_string(&RpcResponse::<String> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some("Missing required parameter: url".to_string()),
                    id: req.id,
                })
                .unwrap();
            }

            let dest_dir = params
                .get("destination_path")
                .or_else(|| params.get("target_dir"))
                .and_then(|v| v.as_str())
                .unwrap_or(".")
                .to_string();

            let filename = params
                .get("filename")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());

            let concurrency = params
                .get("concurrency")
                .and_then(|v| v.as_u64())
                .unwrap_or(16) as u32;

            let limit_bps = params.get("limit_bps").and_then(|v| v.as_u64());

            let config = TaskConfig {
                id: None,
                url,
                destination_path: dest_dir,
                filename,
                concurrency,
                limit_bps,
                headers: HashMap::new(),
                cookies: Vec::new(),
                category: None,
            };

            match coord.add_task(config).await {
                Ok(task_id) => serde_json::to_string(&RpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(serde_json::json!({ "task_id": task_id })),
                    error: None,
                    id: req.id,
                })
                .unwrap(),
                Err(e) => serde_json::to_string(&RpcResponse::<String> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(e.to_string()),
                    id: req.id,
                })
                .unwrap(),
            }
        }
        "rdm.pauseDownload" | "download.pause" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let task_id = params
                .get("task_id")
                .or_else(|| params.get("id"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            match coord.pause_task(task_id).await {
                Ok(()) => serde_json::to_string(&RpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(true),
                    error: None,
                    id: req.id,
                })
                .unwrap(),
                Err(e) => serde_json::to_string(&RpcResponse::<bool> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(e.to_string()),
                    id: req.id,
                })
                .unwrap(),
            }
        }
        "rdm.resumeDownload" | "download.resume" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let task_id = params
                .get("task_id")
                .or_else(|| params.get("id"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            match coord.resume_task(task_id).await {
                Ok(()) => serde_json::to_string(&RpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(true),
                    error: None,
                    id: req.id,
                })
                .unwrap(),
                Err(e) => serde_json::to_string(&RpcResponse::<bool> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(e.to_string()),
                    id: req.id,
                })
                .unwrap(),
            }
        }
        "rdm.cancelDownload" | "download.cancel" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let task_id = params
                .get("task_id")
                .or_else(|| params.get("id"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let delete_file = params
                .get("delete_file")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);

            match coord.cancel_task(task_id, delete_file).await {
                Ok(()) => serde_json::to_string(&RpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(true),
                    error: None,
                    id: req.id,
                })
                .unwrap(),
                Err(e) => serde_json::to_string(&RpcResponse::<bool> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(e.to_string()),
                    id: req.id,
                })
                .unwrap(),
            }
        }
        "rdm.refreshTaskUrl" | "download.refreshUrl" => {
            let params = req.params.unwrap_or(serde_json::Value::Null);
            let task_id = params
                .get("task_id")
                .or_else(|| params.get("id"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let new_url = params
                .get("new_url")
                .or_else(|| params.get("url"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            match coord
                .refresh_task_url(task_id, new_url, HashMap::new(), Vec::new())
                .await
            {
                Ok(()) => serde_json::to_string(&RpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(true),
                    error: None,
                    id: req.id,
                })
                .unwrap(),
                Err(e) => serde_json::to_string(&RpcResponse::<bool> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(e.to_string()),
                    id: req.id,
                })
                .unwrap(),
            }
        }
        _ => serde_json::to_string(&RpcResponse::<String> {
            jsonrpc: "2.0".to_string(),
            result: None,
            error: Some("Method not implemented".to_string()),
            id: req.id,
        })
        .unwrap(),
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Starting RDM Headless Daemon on 127.0.0.1:6800...");
    initialize("rdm_daemon.db".to_string(), 32)?;
    let coordinator = get_instance();

    // Listen on localhost TCP socket for JSON-RPC
    let listener = tokio::net::TcpListener::bind("127.0.0.1:6800").await?;
    println!("RDM Daemon listening for commands.");

    loop {
        let (mut socket, _) = listener.accept().await?;
        let coord = coordinator.clone();

        tokio::spawn(async move {
            use tokio::io::{AsyncReadExt, AsyncWriteExt};
            let mut buf = vec![0u8; 4096];
            if let Ok(n) = socket.read(&mut buf).await {
                if n == 0 {
                    return;
                }
                if let Ok(req) = serde_json::from_slice::<RpcRequest>(&buf[..n]) {
                    let resp = handle_rpc_request(&coord, req).await;
                    let _ = socket.write_all(resp.as_bytes()).await;
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_rpc_get_all_tasks() {
        let coord = Arc::new(EngineCoordinator::new());
        let req = RpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "rdm.getAllTasks".to_string(),
            params: None,
            id: 1,
        };

        let resp_str = handle_rpc_request(&coord, req).await;
        let resp: RpcResponse<Vec<rdm_engine::models::DownloadTaskModel>> =
            serde_json::from_str(&resp_str).unwrap();
        assert_eq!(resp.id, 1);
        assert!(resp.error.is_none());
        assert_eq!(resp.result.unwrap().len(), 0);
    }

    #[tokio::test]
    async fn test_rpc_unknown_method() {
        let coord = Arc::new(EngineCoordinator::new());
        let req = RpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "rdm.nonExistentMethod".to_string(),
            params: None,
            id: 42,
        };

        let resp_str = handle_rpc_request(&coord, req).await;
        let resp: RpcResponse<String> = serde_json::from_str(&resp_str).unwrap();
        assert_eq!(resp.id, 42);
        assert_eq!(resp.error, Some("Method not implemented".to_string()));
    }

    #[tokio::test]
    async fn test_rpc_add_download_missing_url() {
        let coord = Arc::new(EngineCoordinator::new());
        let req = RpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "download.add".to_string(),
            params: Some(serde_json::json!({})),
            id: 2,
        };

        let resp_str = handle_rpc_request(&coord, req).await;
        let resp: RpcResponse<String> = serde_json::from_str(&resp_str).unwrap();
        assert_eq!(resp.id, 2);
        assert!(resp.error.unwrap().contains("Missing required parameter: url"));
    }
}
