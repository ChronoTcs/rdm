use rdm_engine::{
    coordinator::{get_instance, initialize},
    models::{CookieDto, DownloadTaskModel, TaskConfig, TelemetryEvent},
};
use std::collections::HashMap;
use std::panic::catch_unwind;

pub fn init_engine(db_path: String, max_concurrency: usize) -> Result<(), String> {
    catch_unwind(|| {
        initialize(db_path, max_concurrency).map_err(|e| e.to_string())
    })
    .unwrap_or_else(|_| Err("Panic during engine initialization".to_string()))
}

pub async fn add_download(config: TaskConfig) -> Result<String, String> {
    let coordinator = get_instance();
    coordinator
        .add_task(config)
        .await
        .map_err(|e| e.to_string())
}

pub async fn pause_download(task_id: String) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .pause_task(&task_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn resume_download(task_id: String) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .resume_task(&task_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn cancel_download(task_id: String, delete_file: bool) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .cancel_task(&task_id, delete_file)
        .await
        .map_err(|e| e.to_string())
}

pub async fn refresh_task_url(
    task_id: String,
    new_url: String,
    headers: HashMap<String, String>,
    cookies: Vec<CookieDto>,
) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .refresh_task_url(&task_id, &new_url, headers, cookies)
        .await
        .map_err(|e| e.to_string())
}

pub async fn set_task_bandwidth_limit(task_id: String, limit_bps: u64) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .set_task_limit(&task_id, limit_bps)
        .await
        .map_err(|e| e.to_string())
}

pub async fn set_global_bandwidth_limit(limit_bps: u64) -> Result<(), String> {
    let coordinator = get_instance();
    coordinator
        .set_global_limit(limit_bps)
        .await
        .map_err(|e| e.to_string())
}

pub async fn fetch_all_tasks() -> Result<Vec<DownloadTaskModel>, String> {
    let coordinator = get_instance();
    coordinator
        .get_all_tasks()
        .await
        .map_err(|e| e.to_string())
}

pub fn subscribe_telemetry() -> tokio::sync::broadcast::Receiver<TelemetryEvent> {
    let coordinator = get_instance();
    coordinator.subscribe_telemetry()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_bridge_init_and_fetch() {
        let init_res = init_engine("test.db".to_string(), 16);
        assert!(init_res.is_ok());

        let tasks = fetch_all_tasks().await.unwrap();
        assert_eq!(tasks.len(), 0);
    }
}
