use rdm_engine::{
    coordinator::{get_instance, initialize},
    models::{TaskConfig, TaskStatus},
};
use std::collections::HashMap;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        print_usage();
        return Ok(());
    }

    initialize("rdm.db".to_string(), 16)?;
    let coordinator = get_instance();

    match args[1].as_str() {
        "download" => {
            if args.len() < 3 {
                eprintln!("Usage: rdm download <URL> [--dest <PATH>] [--concurrency <N>]");
                return Ok(());
            }
            let url = args[2].clone();
            let dest = if args.len() > 4 && args[3] == "--dest" {
                args[4].clone()
            } else {
                ".".to_string()
            };

            println!("Initiating RDM high-performance download for: {}", url);
            let config = TaskConfig {
                id: None,
                url: url.clone(),
                destination_path: dest,
                filename: None,
                concurrency: 16,
                limit_bps: None,
                headers: HashMap::new(),
                cookies: Vec::new(),
                category: None,
            };

            let task_id = coordinator.add_task(config).await?;
            println!("Task created with ID: {}", task_id);

            let mut rx = coordinator.subscribe_telemetry();
            while let Ok(event) = rx.recv().await {
                match event {
                    rdm_engine::models::TelemetryEvent::Progress {
                        downloaded_bytes,
                        total_bytes,
                        speed_bps,
                        eta_seconds,
                        ..
                    } => {
                        let pct = if total_bytes > 0 {
                            (downloaded_bytes as f64 / total_bytes as f64) * 100.0
                        } else {
                            0.0
                        };
                        print!(
                            "\rProgress: {:.1}% | Speed: {:.2} MB/s | ETA: {}s",
                            pct,
                            speed_bps as f64 / 1_000_000.0,
                            eta_seconds
                        );
                        use std::io::Write;
                        let _ = std::io::stdout().flush();
                    }
                    rdm_engine::models::TelemetryEvent::StatusChanged { new_status, .. } => {
                        if new_status == TaskStatus::Completed {
                            println!("\nDownload completed successfully!");
                            break;
                        } else if new_status == TaskStatus::Error {
                            println!("\nDownload error encountered.");
                            break;
                        }
                    }
                    _ => {}
                }
            }
        }
        "list" => {
            let tasks = coordinator.get_all_tasks().await?;
            println!("{:<36} {:<24} {:<12} {:<10}", "ID", "Filename", "Status", "Progress");
            for t in tasks {
                let pct = if t.total_bytes > 0 {
                    (t.downloaded_bytes as f64 / t.total_bytes as f64) * 100.0
                } else {
                    0.0
                };
                println!(
                    "{:<36} {:<24} {:<12?} {:.1}%",
                    t.id, t.filename, t.status, pct
                );
            }
        }
        "pause" => {
            if args.len() < 3 {
                eprintln!("Usage: rdm pause <TASK_ID>");
                return Ok(());
            }
            coordinator.pause_task(&args[2]).await?;
            println!("Paused task {}", args[2]);
        }
        "resume" => {
            if args.len() < 3 {
                eprintln!("Usage: rdm resume <TASK_ID>");
                return Ok(());
            }
            coordinator.resume_task(&args[2]).await?;
            println!("Resumed task {}", args[2]);
        }
        "cancel" => {
            if args.len() < 3 {
                eprintln!("Usage: rdm cancel <TASK_ID>");
                return Ok(());
            }
            coordinator.cancel_task(&args[2], false).await?;
            println!("Cancelled task {}", args[2]);
        }
        "refresh-url" => {
            if args.len() < 4 {
                eprintln!("Usage: rdm refresh-url <TASK_ID> <NEW_URL>");
                return Ok(());
            }
            coordinator
                .refresh_task_url(&args[2], &args[3], HashMap::new(), Vec::new())
                .await?;
            println!("Refreshed URL for task {}", args[2]);
        }
        "status" => {
            if args.len() < 3 {
                eprintln!("Usage: rdm status <TASK_ID>");
                return Ok(());
            }
            let tasks = coordinator.get_all_tasks().await?;
            if let Some(t) = tasks.into_iter().find(|t| t.id == args[2]) {
                println!("Task ID:        {}", t.id);
                println!("URL:            {}", t.url);
                println!("Filename:       {}", t.filename);
                println!("Destination:    {}", t.destination_path);
                println!("Status:         {:?}", t.status);
                println!("Downloaded:     {} / {} bytes", t.downloaded_bytes, t.total_bytes);
                println!("Speed:          {:.2} MB/s", t.speed_bps as f64 / 1_000_000.0);
                println!("ETA:            {}s", t.eta_seconds);
                println!("Connections:    {}", t.active_connections);
            } else {
                eprintln!("Task not found: {}", args[2]);
            }
        }
        _ => print_usage(),
    }

    Ok(())
}

fn print_usage() {
    println!("RDM (Rust Download Manager) CLI");
    println!("Usage:");
    println!("  rdm download <URL> [--dest <PATH>]       Start a download");
    println!("  rdm list                                 List all tasks");
    println!("  rdm status <TASK_ID>                     Show task details");
    println!("  rdm pause <TASK_ID>                      Pause a task");
    println!("  rdm resume <TASK_ID>                     Resume a task");
    println!("  rdm cancel <TASK_ID>                     Cancel a task");
    println!("  rdm refresh-url <TASK_ID> <NEW_URL>      Update expired task URL");
}
