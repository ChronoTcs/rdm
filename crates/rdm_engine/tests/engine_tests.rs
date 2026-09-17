use rdm_engine::{
    preallocate_sparse_file, write_at, EngineCoordinator, HierarchicalBandwidthLimiter,
    ResumeBitmask, TaskCategory, TokenBucket,
};
use tempfile::NamedTempFile;

#[test]
fn test_resume_bitmask_operations() {
    let mut bitmask = ResumeBitmask::new(10 * 1024 * 1024); // 10MB = 40 blocks
    assert_eq!(bitmask.num_blocks, 40);
    assert_eq!(bitmask.count_downloaded_blocks(), 0);

    bitmask.mark_block_downloaded(5);
    assert!(bitmask.is_block_downloaded(5));
    assert!(!bitmask.is_block_downloaded(6));
    assert_eq!(bitmask.count_downloaded_blocks(), 1);

    // Mark range from block 0 to 9
    bitmask.mark_range_downloaded(0, 10 * 256 * 1024 - 1);
    assert_eq!(bitmask.count_downloaded_blocks(), 10);
}

#[test]
fn test_sparse_file_and_positional_io() {
    let temp = NamedTempFile::new().unwrap();
    let file = temp.as_file();
    let target_size = 5 * 1024 * 1024;

    assert!(preallocate_sparse_file(file, target_size, temp.path()).is_ok());

    // Write at offset 1MB
    let payload = b"TEST_CHUNK_AT_1MB";
    let written = write_at(file, 1024 * 1024, payload).unwrap();
    assert_eq!(written, payload.len());
}

#[test]
fn test_task_category_routing() {
    assert_eq!(TaskCategory::from_extension(".zip"), TaskCategory::Compressed);
    assert_eq!(TaskCategory::from_extension("archive.tar.gz"), TaskCategory::Compressed);
    assert_eq!(TaskCategory::from_extension(".mp4"), TaskCategory::Video);
    assert_eq!(TaskCategory::from_extension("song.flac"), TaskCategory::Audio);
    assert_eq!(TaskCategory::from_extension("doc.pdf"), TaskCategory::Documents);
    assert_eq!(TaskCategory::from_extension("setup.exe"), TaskCategory::Programs);
    assert_eq!(TaskCategory::from_extension("image.png"), TaskCategory::General);
}

#[tokio::test]
async fn test_bandwidth_limiter_hierarchy() {
    let limiter = HierarchicalBandwidthLimiter::new(Some(500_000));
    let task_bucket = TokenBucket::new(Some(100_000));

    let allowed = limiter
        .acquire_bandwidth(Some(&task_bucket), 10_000)
        .await;
    assert_eq!(allowed, 10_000);
}

#[tokio::test]
async fn test_coordinator_lifecycle() {
    let coordinator = EngineCoordinator::new();
    let tasks = coordinator.get_all_tasks().await.unwrap();
    assert_eq!(tasks.len(), 0);
}

#[test]
fn test_dynamic_bisection_work_stealing_pipeline() {
    use rdm_engine::SegmentManager;
    let total_bytes = 20 * 1024 * 1024; // 20 MB
    let mgr = SegmentManager::new(total_bytes, 4);
    mgr.initialize_segments(1); // 1 worker with 20 MB [0..20971519]

    let active = mgr.get_active_workers_for_resume();
    assert_eq!(active.len(), 1);
    assert_eq!(active[0].start_offset, 0);
    assert_eq!(active[0].end_offset, total_bytes - 1);

    // Advance worker 1 by 2 MB
    mgr.update_worker_progress(1, 2 * 1024 * 1024, 5 * 1024 * 1024);

    // Rebalance: splits worker 1 in half
    let rebalance = mgr.try_work_steal_rebalance();
    assert!(rebalance.is_some());
    let (new_conn_id, stolen) = rebalance.unwrap();
    assert_eq!(new_conn_id, 2);

    // Verify worker 1 end offset was truncated
    let worker1_end = mgr.get_worker_end_offset(1).unwrap();
    assert_eq!(worker1_end + 1, stolen.start);
    assert_eq!(stolen.end, total_bytes - 1);

    // Active workers for resume should now be 2
    let active_now = mgr.get_active_workers_for_resume();
    assert_eq!(active_now.len(), 2);
}

#[test]
fn test_resume_missing_ranges_reconstruction() {
    use rdm_engine::SegmentManager;
    let total_bytes = 1024 * 1024; // 1 MB = 4 blocks of 256KB
    let mut bitmask = ResumeBitmask::new(total_bytes);

    // Simulate block 0 and block 1 already downloaded
    bitmask.mark_block_downloaded(0);
    bitmask.mark_block_downloaded(1);

    // Find missing ranges
    let missing = bitmask.get_missing_ranges();
    assert_eq!(missing.len(), 1);
    assert_eq!(missing[0].start, 512 * 1024);
    assert_eq!(missing[0].end, 1024 * 1024 - 1);

    // Initialize SegmentManager from missing ranges
    let mgr = SegmentManager::new(total_bytes, 4);
    mgr.initialize_from_ranges(&missing);

    let active = mgr.get_active_workers_for_resume();
    assert_eq!(active.len(), 1);
    assert_eq!(active[0].start_offset, 512 * 1024);
    assert_eq!(active[0].end_offset, 1024 * 1024 - 1);
}
