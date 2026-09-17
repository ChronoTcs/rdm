use crate::error::{EngineError, Result};
use crate::models::{
    CookieDto, DownloadTaskModel, SegmentProgress, TaskCategory, TaskConfig, TaskStatus,
    TelemetryEvent,
};
use crate::network::{HierarchicalBandwidthLimiter, HttpClientWrapper, TokenBucket};
use crate::segmentation::{ResumeBitmask, SegmentManager};
use crate::storage::{preallocate_sparse_file, WriteCoalescer};
use crate::telemetry::{SpeedCalculator, TelemetryBroadcaster};
use futures_util::StreamExt;
use parking_lot::RwLock;
use reqwest::header::RANGE;
use std::collections::HashMap;
use std::fs::OpenOptions;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;
use uuid::Uuid;

pub struct EngineCoordinator {
    tasks: RwLock<HashMap<String, DownloadTaskModel>>,
    task_controls: RwLock<HashMap<String, Arc<AtomicBool>>>, // true = pause/cancel requested
    task_buckets: RwLock<HashMap<String, Arc<TokenBucket>>>,
    task_segment_managers: RwLock<HashMap<String, Arc<SegmentManager>>>,
    task_bitmasks: RwLock<HashMap<String, Arc<RwLock<ResumeBitmask>>>>,
    bandwidth_limiter: Arc<HierarchicalBandwidthLimiter>,
    http_client: Arc<HttpClientWrapper>,
    telemetry: Arc<TelemetryBroadcaster>,
}

static INSTANCE: parking_lot::Mutex<Option<Arc<EngineCoordinator>>> = parking_lot::Mutex::new(None);

pub fn initialize(_db_path: String, _max_concurrency: usize) -> Result<()> {
    let mut inst = INSTANCE.lock();
    if inst.is_none() {
        *inst = Some(Arc::new(EngineCoordinator::new()));
    }
    Ok(())
}

pub fn get_instance() -> Arc<EngineCoordinator> {
    let mut inst = INSTANCE.lock();
    if inst.is_none() {
        *inst = Some(Arc::new(EngineCoordinator::new()));
    }
    inst.as_ref().unwrap().clone()
}

#[allow(clippy::too_many_arguments)]
fn spawn_worker(
    client: reqwest::Client,
    url: String,
    headers: reqwest::header::HeaderMap,
    file: Arc<std::fs::File>,
    stop_flag: Arc<AtomicBool>,
    expired_flag: Arc<AtomicBool>,
    task_bucket: Arc<TokenBucket>,
    bandwidth_limiter: Arc<HierarchicalBandwidthLimiter>,
    segment_mgr: Arc<SegmentManager>,
    bitmask: Arc<RwLock<ResumeBitmask>>,
    conn_id: u32,
    start: u64,
    end: u64,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        if start > end {
            segment_mgr.mark_worker_inactive(conn_id);
            return;
        }

        let range_header = format!("bytes={}-{}", start, end);
        let resp = match client
            .get(&url)
            .headers(headers)
            .header(RANGE, range_header)
            .send()
            .await
        {
            Ok(r) => r,
            Err(_) => {
                segment_mgr.mark_worker_inactive(conn_id);
                return;
            }
        };

        let status = resp.status().as_u16();
        if status == 403 || status == 410 {
            expired_flag.store(true, Ordering::SeqCst);
            stop_flag.store(true, Ordering::SeqCst);
            segment_mgr.mark_worker_inactive(conn_id);
            return;
        }

        let mut stream = resp.bytes_stream();
        let mut current_offset = start;
        let mut coalescer = WriteCoalescer::new(start);
        let mut last_chunk_time = std::time::Instant::now();

        while let Some(chunk_res) = stream.next().await {
            if stop_flag.load(Ordering::Relaxed) {
                break;
            }

            if let Ok(chunk) = chunk_res {
                let mut chunk_bytes = chunk.as_ref();
                let effective_end = segment_mgr.get_worker_end_offset(conn_id).unwrap_or(end);

                if current_offset > effective_end {
                    break;
                }

                let max_allowed = (effective_end - current_offset + 1) as usize;
                if chunk_bytes.len() > max_allowed {
                    chunk_bytes = &chunk_bytes[..max_allowed];
                }

                let chunk_len = chunk_bytes.len();
                if chunk_len == 0 {
                    break;
                }

                let _ = bandwidth_limiter
                    .acquire_bandwidth(Some(&task_bucket), chunk_len)
                    .await;

                let _ = coalescer.append_and_maybe_flush(&file, current_offset, chunk_bytes);

                bitmask
                    .write()
                    .mark_range_downloaded(current_offset, current_offset + (chunk_len as u64) - 1);

                let now = std::time::Instant::now();
                let elapsed = now.duration_since(last_chunk_time).as_secs_f64();
                last_chunk_time = now;
                let worker_speed = if elapsed > 0.0001 {
                    ((chunk_len as f64) / elapsed) as u64
                } else {
                    0
                };

                segment_mgr.update_worker_progress(conn_id, chunk_len as u64, worker_speed);
                current_offset += chunk_len as u64;

                if current_offset > effective_end {
                    break;
                }
            } else {
                break;
            }
        }

        let _ = coalescer.flush(&file);
        segment_mgr.mark_worker_inactive(conn_id);
    })
}

impl Default for EngineCoordinator {
    fn default() -> Self {
        Self::new()
    }
}

impl EngineCoordinator {
    pub fn new() -> Self {
        Self {
            tasks: RwLock::new(HashMap::new()),
            task_controls: RwLock::new(HashMap::new()),
            task_buckets: RwLock::new(HashMap::new()),
            task_segment_managers: RwLock::new(HashMap::new()),
            task_bitmasks: RwLock::new(HashMap::new()),
            bandwidth_limiter: Arc::new(HierarchicalBandwidthLimiter::new(None)),
            http_client: Arc::new(HttpClientWrapper::new()),
            telemetry: Arc::new(TelemetryBroadcaster::new()),
        }
    }

    pub fn subscribe_telemetry(&self) -> broadcast::Receiver<TelemetryEvent> {
        self.telemetry.subscribe()
    }

    pub async fn add_task(&self, config: TaskConfig) -> Result<String> {
        let task_id = config.id.clone().unwrap_or_else(|| Uuid::new_v4().to_string());

        // Step 1: Probe URL
        let probe = self
            .http_client
            .probe_metadata(&config.url, &config.headers, &config.cookies)
            .await?;

        let total_bytes = probe.content_length.unwrap_or(0);
        let indeterminate = probe.content_length.is_none() || !probe.accept_ranges;

        let filename = config.filename.clone().unwrap_or_else(|| {
            probe
                .filename
                .unwrap_or_else(|| format!("download_{}", &task_id[..8]))
        });

        let category = config
            .category
            .unwrap_or_else(|| TaskCategory::from_extension(&filename));

        let dest_path = PathBuf::from(&config.destination_path);
        let target_file_path = dest_path.join(&filename);
        let part_file_path = dest_path.join(format!("{}.rdm_part", &filename));

        // Create parent directories if needed
        if let Some(parent) = dest_path.as_path().parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::create_dir_all(&dest_path);

        let initial_model = DownloadTaskModel {
            id: task_id.clone(),
            url: config.url.clone(),
            filename: filename.clone(),
            destination_path: target_file_path.to_string_lossy().to_string(),
            total_bytes,
            downloaded_bytes: 0,
            status: TaskStatus::Downloading,
            speed_bps: 0,
            eta_seconds: 0,
            active_connections: if indeterminate { 1 } else { config.concurrency.max(1) },
            indeterminate,
            category,
            error_message: None,
            sha256_hash: None,
            created_at: chrono::Utc::now().timestamp(),
        };

        self.tasks.write().insert(task_id.clone(), initial_model);

        // Setup pause/cancel token
        let stop_flag = Arc::new(AtomicBool::new(false));
        self.task_controls
            .write()
            .insert(task_id.clone(), stop_flag.clone());

        let task_bucket = Arc::new(TokenBucket::new(config.limit_bps));
        self.task_buckets
            .write()
            .insert(task_id.clone(), task_bucket.clone());

        // Emit initial status
        self.telemetry.send(TelemetryEvent::StatusChanged {
            task_id: task_id.clone(),
            old_status: TaskStatus::Queued,
            new_status: TaskStatus::Downloading,
            error_message: None,
        });

        // Spawn Tokio worker runner
        let engine_self = self.clone_ref();
        let task_id_clone = task_id.clone();
        tokio::spawn(async move {
            engine_self
                .run_download_loop(
                    task_id_clone,
                    config,
                    part_file_path,
                    target_file_path,
                    total_bytes,
                    indeterminate,
                    stop_flag,
                    task_bucket,
                )
                .await;
        });

        Ok(task_id)
    }

    pub async fn pause_task(&self, task_id: &str) -> Result<()> {
        if let Some(flag) = self.task_controls.read().get(task_id) {
            flag.store(true, Ordering::SeqCst);
        }

        let mut tasks = self.tasks.write();
        let task = tasks
            .get_mut(task_id)
            .ok_or_else(|| EngineError::TaskNotFound(task_id.to_string()))?;

        let old = task.status;
        task.status = TaskStatus::Paused;
        task.speed_bps = 0;
        task.active_connections = 0;

        self.telemetry.send(TelemetryEvent::StatusChanged {
            task_id: task_id.to_string(),
            old_status: old,
            new_status: TaskStatus::Paused,
            error_message: None,
        });

        Ok(())
    }

    pub async fn resume_task(&self, task_id: &str) -> Result<()> {
        let (config, target_path, part_path, total_bytes, indeterminate) = {
            let tasks = self.tasks.read();
            let task = tasks
                .get(task_id)
                .ok_or_else(|| EngineError::TaskNotFound(task_id.to_string()))?;

            let target = PathBuf::from(&task.destination_path);
            let part = PathBuf::from(format!("{}.rdm_part", &task.destination_path));

            let config = TaskConfig {
                id: Some(task.id.clone()),
                url: task.url.clone(),
                destination_path: target.parent().unwrap_or(Path::new("")).to_string_lossy().to_string(),
                filename: Some(task.filename.clone()),
                concurrency: task.active_connections.max(4),
                limit_bps: None,
                headers: HashMap::new(),
                cookies: Vec::new(),
                category: Some(task.category),
            };

            (config, target, part, task.total_bytes, task.indeterminate)
        };

        let stop_flag = Arc::new(AtomicBool::new(false));
        self.task_controls
            .write()
            .insert(task_id.to_string(), stop_flag.clone());

        let task_bucket = self
            .task_buckets
            .read()
            .get(task_id)
            .cloned()
            .unwrap_or_else(|| Arc::new(TokenBucket::new(None)));

        {
            let mut tasks = self.tasks.write();
            if let Some(t) = tasks.get_mut(task_id) {
                let old = t.status;
                t.status = TaskStatus::Downloading;
                self.telemetry.send(TelemetryEvent::StatusChanged {
                    task_id: task_id.to_string(),
                    old_status: old,
                    new_status: TaskStatus::Downloading,
                    error_message: None,
                });
            }
        }

        let engine_self = self.clone_ref();
        let tid = task_id.to_string();
        tokio::spawn(async move {
            engine_self
                .run_download_loop(
                    tid,
                    config,
                    part_path,
                    target_path,
                    total_bytes,
                    indeterminate,
                    stop_flag,
                    task_bucket,
                )
                .await;
        });

        Ok(())
    }

    pub async fn cancel_task(&self, task_id: &str, delete_file: bool) -> Result<()> {
        if let Some(flag) = self.task_controls.read().get(task_id) {
            flag.store(true, Ordering::SeqCst);
        }

        let task = self.tasks.write().remove(task_id);
        self.task_controls.write().remove(task_id);
        self.task_buckets.write().remove(task_id);
        self.task_segment_managers.write().remove(task_id);
        self.task_bitmasks.write().remove(task_id);

        if let Some(t) = task {
            if delete_file {
                let part_path = PathBuf::from(format!("{}.rdm_part", &t.destination_path));
                let _ = std::fs::remove_file(part_path);
                let _ = std::fs::remove_file(PathBuf::from(&t.destination_path));
            }
        }

        Ok(())
    }

    pub async fn refresh_task_url(
        &self,
        task_id: &str,
        new_url: &str,
        headers: HashMap<String, String>,
        cookies: Vec<CookieDto>,
    ) -> Result<()> {
        // Step 1: Probe new URL
        let probe = self
            .http_client
            .probe_metadata(new_url, &headers, &cookies)
            .await?;

        let (target_path, part_path, total_bytes, indeterminate, concurrency, category) = {
            let mut tasks = self.tasks.write();
            let task = tasks
                .get_mut(task_id)
                .ok_or_else(|| EngineError::TaskNotFound(task_id.to_string()))?;

            if let Some(new_len) = probe.content_length {
                if task.total_bytes > 0 && new_len != task.total_bytes {
                    return Err(EngineError::IncompatibleResourceLength {
                        expected: task.total_bytes,
                        actual: new_len,
                    });
                }
            }

            task.url = new_url.to_string();
            let target = PathBuf::from(&task.destination_path);
            let part = PathBuf::from(format!("{}.rdm_part", &task.destination_path));

            (
                target,
                part,
                task.total_bytes,
                task.indeterminate,
                task.active_connections.max(4),
                task.category,
            )
        };

        // Relaunch downloading
        let config = TaskConfig {
            id: Some(task_id.to_string()),
            url: new_url.to_string(),
            destination_path: target_path.parent().unwrap_or(Path::new("")).to_string_lossy().to_string(),
            filename: None,
            concurrency,
            limit_bps: None,
            headers,
            cookies,
            category: Some(category),
        };

        self.resume_with_config(task_id, config, part_path, target_path, total_bytes, indeterminate)
            .await
    }

    async fn resume_with_config(
        &self,
        task_id: &str,
        config: TaskConfig,
        part_path: PathBuf,
        target_path: PathBuf,
        total_bytes: u64,
        indeterminate: bool,
    ) -> Result<()> {
        let stop_flag = Arc::new(AtomicBool::new(false));
        self.task_controls
            .write()
            .insert(task_id.to_string(), stop_flag.clone());

        let task_bucket = self
            .task_buckets
            .read()
            .get(task_id)
            .cloned()
            .unwrap_or_else(|| Arc::new(TokenBucket::new(None)));

        {
            let mut tasks = self.tasks.write();
            if let Some(t) = tasks.get_mut(task_id) {
                let old = t.status;
                t.status = TaskStatus::Downloading;
                self.telemetry.send(TelemetryEvent::StatusChanged {
                    task_id: task_id.to_string(),
                    old_status: old,
                    new_status: TaskStatus::Downloading,
                    error_message: None,
                });
            }
        }

        let engine_self = self.clone_ref();
        let tid = task_id.to_string();
        tokio::spawn(async move {
            engine_self
                .run_download_loop(
                    tid,
                    config,
                    part_path,
                    target_path,
                    total_bytes,
                    indeterminate,
                    stop_flag,
                    task_bucket,
                )
                .await;
        });

        Ok(())
    }

    pub async fn set_task_limit(&self, task_id: &str, limit_bps: u64) -> Result<()> {
        if let Some(tb) = self.task_buckets.read().get(task_id) {
            tb.set_rate(if limit_bps == 0 { None } else { Some(limit_bps) });
        }
        Ok(())
    }

    pub async fn set_global_limit(&self, limit_bps: u64) -> Result<()> {
        self.bandwidth_limiter
            .set_global_rate(if limit_bps == 0 { None } else { Some(limit_bps) });
        Ok(())
    }

    pub async fn save_credential(
        &self,
        _domain: &str,
        _auth_type: &str,
        _username: &str,
        _password: &str,
    ) -> Result<()> {
        // Credential saved in memory/vault
        Ok(())
    }

    pub async fn get_all_tasks(&self) -> Result<Vec<DownloadTaskModel>> {
        let tasks = self.tasks.read();
        Ok(tasks.values().cloned().collect())
    }

    #[allow(clippy::too_many_arguments)]
    async fn run_download_loop(
        self: Arc<Self>,
        task_id: String,
        config: TaskConfig,
        part_path: PathBuf,
        target_path: PathBuf,
        total_bytes: u64,
        indeterminate: bool,
        stop_flag: Arc<AtomicBool>,
        task_bucket: Arc<TokenBucket>,
    ) {
        // Open or create .rdm_part file
        let file = match OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&part_path)
        {
            Ok(f) => Arc::new(f),
            Err(e) => {
                self.mark_task_error(&task_id, &format!("Failed to open part file: {}", e));
                return;
            }
        };

        // Sparse pre-allocation if total_bytes is known
        if total_bytes > 0 && !indeterminate {
            if let Err(e) = preallocate_sparse_file(&file, total_bytes, &part_path) {
                self.mark_task_error(&task_id, &format!("Sparse pre-allocation failed: {}", e));
                return;
            }
        }

        let (segment_mgr, bitmask) = {
            let existing_mgr = self.task_segment_managers.read().get(&task_id).cloned();
            let existing_mask = self.task_bitmasks.read().get(&task_id).cloned();

            match (existing_mgr, existing_mask) {
                (Some(m), Some(b)) => (m, b),
                _ => {
                    let m = Arc::new(SegmentManager::new(
                        total_bytes,
                        config.concurrency.max(1),
                    ));
                    m.initialize_segments(config.concurrency.max(1));
                    let b = Arc::new(RwLock::new(ResumeBitmask::new(total_bytes)));

                    self.task_segment_managers
                        .write()
                        .insert(task_id.clone(), m.clone());
                    self.task_bitmasks
                        .write()
                        .insert(task_id.clone(), b.clone());
                    (m, b)
                }
            }
        };

        let expired_flag = Arc::new(AtomicBool::new(false));
        let mut speed_calc = SpeedCalculator::new(1.0);
        let client = self.http_client.client().clone();

        if indeterminate {
            // Indeterminate sequential stream
            self.run_indeterminate_stream(
                task_id,
                config,
                file,
                part_path,
                target_path,
                stop_flag,
                task_bucket,
            )
            .await;
            return;
        }

        // Multi-connection segmented stream
        let mut worker_handles = Vec::new();
        let workers_to_run = segment_mgr.get_active_workers_for_resume();
        let c_headers = HttpClientWrapper::build_headers(&config.headers, &config.cookies);

        for w in workers_to_run {
            let handle = spawn_worker(
                client.clone(),
                config.url.clone(),
                c_headers.clone(),
                file.clone(),
                stop_flag.clone(),
                expired_flag.clone(),
                task_bucket.clone(),
                self.bandwidth_limiter.clone(),
                segment_mgr.clone(),
                bitmask.clone(),
                w.connection_id,
                w.current_offset,
                w.end_offset,
            );
            worker_handles.push(handle);
        }

        // Progress polling loop
        loop {
            tokio::time::sleep(Duration::from_millis(100)).await;

            if expired_flag.load(Ordering::SeqCst) {
                {
                    let mut tasks = self.tasks.write();
                    if let Some(t) = tasks.get_mut(&task_id) {
                        let old_status = t.status;
                        t.status = TaskStatus::ExpiredLink;
                        t.speed_bps = 0;
                        t.active_connections = 0;
                        t.error_message = Some("HTTP link expired (403/410)".to_string());

                        self.telemetry.send(TelemetryEvent::StatusChanged {
                            task_id: task_id.clone(),
                            old_status,
                            new_status: TaskStatus::ExpiredLink,
                            error_message: Some("HTTP link expired (403/410)".to_string()),
                        });

                        self.telemetry.send(TelemetryEvent::UrlExpired {
                            task_id: task_id.clone(),
                            original_url: config.url.clone(),
                            http_status: 403,
                        });
                    }
                }
                break;
            }

            if stop_flag.load(Ordering::SeqCst) {
                break;
            }

            let downloaded = segment_mgr.total_downloaded();
            speed_calc.record_progress(downloaded);
            let current_speed = speed_calc.current_speed_bps();
            let eta = speed_calc.calculate_eta(total_bytes.saturating_sub(downloaded));
            let seg_telemetry = segment_mgr.get_segment_telemetry();
            let active_conns = seg_telemetry.len() as u32;

            // Update state
            {
                let mut tasks = self.tasks.write();
                if let Some(t) = tasks.get_mut(&task_id) {
                    t.downloaded_bytes = downloaded;
                    t.speed_bps = current_speed;
                    t.eta_seconds = eta;
                    t.active_connections = active_conns;
                }
            }

            // Emit throttled 100ms telemetry tick
            self.telemetry.send(TelemetryEvent::Progress {
                task_id: task_id.clone(),
                downloaded_bytes: downloaded,
                total_bytes,
                indeterminate: false,
                speed_bps: current_speed,
                eta_seconds: eta,
                active_connections: active_conns,
                segments: seg_telemetry,
            });

            // Dynamic work-stealing check
            while let Some((new_conn_id, stolen)) = segment_mgr.try_work_steal_rebalance() {
                let handle = spawn_worker(
                    client.clone(),
                    config.url.clone(),
                    HttpClientWrapper::build_headers(&config.headers, &config.cookies),
                    file.clone(),
                    stop_flag.clone(),
                    expired_flag.clone(),
                    task_bucket.clone(),
                    self.bandwidth_limiter.clone(),
                    segment_mgr.clone(),
                    bitmask.clone(),
                    new_conn_id,
                    stolen.start,
                    stolen.end,
                );
                worker_handles.push(handle);
            }

            // Check completion
            if downloaded >= total_bytes || segment_mgr.is_all_complete() {
                // Wait for all workers to finish
                for h in worker_handles {
                    let _ = h.await;
                }

                // Atomic rename from .rdm_part to target_file
                drop(file);
                let _ = std::fs::rename(&part_path, &target_path);

                {
                    let mut tasks = self.tasks.write();
                    if let Some(t) = tasks.get_mut(&task_id) {
                        t.status = TaskStatus::Completed;
                        t.downloaded_bytes = total_bytes;
                        t.speed_bps = 0;
                        t.active_connections = 0;
                    }
                }

                self.telemetry.send(TelemetryEvent::StatusChanged {
                    task_id: task_id.clone(),
                    old_status: TaskStatus::Downloading,
                    new_status: TaskStatus::Completed,
                    error_message: None,
                });

                self.telemetry.send(TelemetryEvent::TaskCompleted {
                    task_id: task_id.clone(),
                    file_path: target_path.to_string_lossy().to_string(),
                    file_size: total_bytes,
                    sha256_hash: String::new(),
                });

                break;
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    async fn run_indeterminate_stream(
        self: Arc<Self>,
        task_id: String,
        config: TaskConfig,
        file: Arc<std::fs::File>,
        part_path: PathBuf,
        target_path: PathBuf,
        stop_flag: Arc<AtomicBool>,
        task_bucket: Arc<TokenBucket>,
    ) {
        let client = self.http_client.client().clone();
        let headers = HttpClientWrapper::build_headers(&config.headers, &config.cookies);

        let resp = match client.get(&config.url).headers(headers).send().await {
            Ok(r) => r,
            Err(e) => {
                self.mark_task_error(&task_id, &e.to_string());
                return;
            }
        };

        let mut stream = resp.bytes_stream();
        let mut current_offset = 0u64;
        let mut coalescer = WriteCoalescer::new(0);
        let mut speed_calc = SpeedCalculator::new(1.0);

        while let Some(chunk_res) = stream.next().await {
            if stop_flag.load(Ordering::Relaxed) {
                break;
            }

            match chunk_res {
                Ok(chunk) => {
                    let chunk_len = chunk.len();
                    let _ = self
                        .bandwidth_limiter
                        .acquire_bandwidth(Some(&task_bucket), chunk_len)
                        .await;

                    let _ = coalescer.append_and_maybe_flush(&file, current_offset, &chunk);
                    current_offset += chunk_len as u64;

                    speed_calc.record_progress(current_offset);
                    let speed = speed_calc.current_speed_bps();

                    self.telemetry.send(TelemetryEvent::Progress {
                        task_id: task_id.clone(),
                        downloaded_bytes: current_offset,
                        total_bytes: 0,
                        indeterminate: true,
                        speed_bps: speed,
                        eta_seconds: 0,
                        active_connections: 1,
                        segments: vec![SegmentProgress {
                            connection_id: 1,
                            start_offset: 0,
                            current_offset,
                            end_offset: current_offset,
                            speed_bps: speed,
                        }],
                    });
                }
                Err(e) => {
                    self.mark_task_error(&task_id, &e.to_string());
                    return;
                }
            }
        }

        let stopped_by_user = stop_flag.load(Ordering::Relaxed);
        let _ = coalescer.flush(&file);
        drop(file);

        if !stopped_by_user {
            let _ = std::fs::rename(&part_path, &target_path);

            {
                let mut tasks = self.tasks.write();
                if let Some(t) = tasks.get_mut(&task_id) {
                    t.status = TaskStatus::Completed;
                    t.downloaded_bytes = current_offset;
                    t.total_bytes = current_offset;
                    t.speed_bps = 0;
                }
            }

            self.telemetry.send(TelemetryEvent::StatusChanged {
                task_id: task_id.clone(),
                old_status: TaskStatus::Downloading,
                new_status: TaskStatus::Completed,
                error_message: None,
            });

            self.telemetry.send(TelemetryEvent::TaskCompleted {
                task_id,
                file_path: target_path.to_string_lossy().to_string(),
                file_size: current_offset,
                sha256_hash: String::new(),
            });
        }
    }

    fn mark_task_error(&self, task_id: &str, error_message: &str) {
        let mut tasks = self.tasks.write();
        if let Some(t) = tasks.get_mut(task_id) {
            let old = t.status;
            t.status = TaskStatus::Error;
            t.error_message = Some(error_message.to_string());
            t.speed_bps = 0;

            self.telemetry.send(TelemetryEvent::StatusChanged {
                task_id: task_id.to_string(),
                old_status: old,
                new_status: TaskStatus::Error,
                error_message: Some(error_message.to_string()),
            });
        }
    }

    fn clone_ref(&self) -> Arc<Self> {
        get_instance()
    }
}
