use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

#[derive(Parser)]
#[command(name = "intrada")]
#[command(about = "Intrada project management CLI")]
#[command(version = "1.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Database operations
    #[command(subcommand)]
    Db(DbCommands),
    /// Build operations
    #[command(subcommand)]
    Build(BuildCommands),
    /// Development operations
    #[command(subcommand)]
    Dev(DevCommands),
    /// Server operations
    #[command(subcommand)]
    Server(ServerCommands),
    /// iOS operations
    #[command(subcommand)]
    Ios(IosCommands),
    /// Full setup and development workflow
    Setup,
    /// Run full development environment
    Start {
        #[arg(short, long)]
        logs: bool,
    },
    /// Quick start (skip type generation)
    Quick {
        #[arg(short, long)]
        logs: bool,
    },
    /// Rebuild and run development environment
    Rebuild {
        #[arg(short, long)]
        logs: bool,
    },
    /// Stream logs from various components
    #[command(subcommand)]
    Logs(LogCommands),
    /// Test operations
    #[command(subcommand)]
    Test(TestCommands),
    /// Clean operations
    #[command(subcommand)]
    Clean(CleanCommands),
    /// Watch for changes and rebuild
    Watch,
    /// Format all code
    Format,
    /// Run linters
    Lint,
    /// Check dependencies
    #[command(subcommand)]
    Deps(DepsCommands),
    /// Run benchmarks
    Bench,
    /// Health check for development environment
    Doctor,
}

#[derive(Subcommand)]
enum DbCommands {
    /// Clean all data from database
    Clean {
        #[arg(short, long)]
        force: bool,
    },
    /// Seed database with sample data
    Seed,
    /// Clean and then seed database
    Reset {
        #[arg(short, long)]
        force: bool,
    },
    /// Show database status
    Status,
}

#[derive(Subcommand)]
enum BuildCommands {
    /// Build shared Rust code
    Shared,
    /// Build server
    Server,
    /// Build iOS app
    Ios,
    /// Build all components
    All,
    /// Generate type bindings
    Types,
    /// Build and generate types
    Full,
    /// Build and test Crux core
    Core,
    /// Clean and rebuild all components
    Rebuild,
}

#[derive(Subcommand)]
enum DevCommands {
    /// Start full development environment
    Start,
    /// Quick start (skip type generation)
    Quick,
    /// Stop all development services
    Stop,
    /// Show development status
    Status,
}

#[derive(Subcommand)]
enum ServerCommands {
    /// Build server
    Build,
    /// Run server
    Run,
    /// Build and run server
    Start,
    /// Rebuild and run server
    Rebuild,
    /// Stop server
    Stop,
    /// Show server logs
    Logs,
    /// Check server status
    Status,
}

#[derive(Subcommand)]
enum IosCommands {
    /// Build iOS app
    Build,
    /// Run iOS app in simulator
    Run,
    /// Build and run iOS app
    Start,
    /// Rebuild and run iOS app
    Rebuild,
    /// List available simulators
    Simulators,
}

#[derive(Subcommand)]
enum LogCommands {
    /// Stream server logs
    Server,
    /// Stream iOS simulator logs
    Ios,
    /// Stream PostgreSQL logs
    Database,
    /// Stream all logs (multiplexed)
    All,
    /// Stream Docker logs
    Docker,
}

#[derive(Subcommand)]
enum TestCommands {
    /// Test Crux core (shared business logic)
    Core,
    /// Test server API
    Server,
    /// Test iOS app
    Ios,
    /// Test web app
    Web,
    /// Test all components
    All,
}

#[derive(Subcommand)]
enum CleanCommands {
    /// Clean all build artifacts
    All,
    /// Clean shared Rust artifacts
    Shared,
    /// Clean server build artifacts
    Server,
    /// Clean iOS build artifacts and derived data
    Ios,
    /// Clean web build artifacts
    Web,
}

#[derive(Subcommand)]
enum DepsCommands {
    /// Check for outdated dependencies
    Check,
    /// Update dependencies
    Update,
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Db(db_cmd) => handle_db_command(db_cmd),
        Commands::Build(build_cmd) => handle_build_command(build_cmd),
        Commands::Dev(dev_cmd) => handle_dev_command(dev_cmd),
        Commands::Server(server_cmd) => handle_server_command(server_cmd),
        Commands::Ios(ios_cmd) => handle_ios_command(ios_cmd),
        Commands::Setup => handle_setup(),
        Commands::Start { logs } => handle_start(logs),
        Commands::Quick { logs } => handle_quick(logs),
        Commands::Rebuild { logs } => handle_rebuild(logs),
        Commands::Logs(log_cmd) => handle_logs_command(log_cmd),
        Commands::Test(test_cmd) => handle_test_command(test_cmd),
        Commands::Clean(clean_cmd) => handle_clean_command(clean_cmd),
        Commands::Watch => handle_watch(),
        Commands::Format => handle_format(),
        Commands::Lint => handle_lint(),
        Commands::Deps(deps_cmd) => handle_deps_command(deps_cmd),
        Commands::Bench => handle_bench(),
        Commands::Doctor => handle_doctor(),
    };

    if let Err(e) = result {
        eprintln!("{} {}", "❌ Error:".red().bold(), e);
        std::process::exit(1);
    }
}

fn handle_db_command(cmd: DbCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        DbCommands::Clean { force } => {
            print_step("Cleaning database");
            let mut args = vec!["./cleanup-db.sh"];
            if force {
                args.push("--force");
            }
            run_command("bash", &args, Some("server"))?;
            print_success("Database cleaned");
        }
        DbCommands::Seed => {
            print_step("Seeding database");
            run_command("bash", &["./seed-db.sh"], Some("server"))?;
            print_success("Database seeded");
        }
        DbCommands::Reset { force } => {
            print_step("Resetting database");
            let mut args = vec!["./reset-db.sh"];
            if force {
                args.push("--force");
            }
            run_command("bash", &args, Some("server"))?;
            print_success("Database reset");
        }
        DbCommands::Status => {
            print_step("Checking database status");
            // Check if PostgreSQL container is running
            let output = Command::new("docker-compose")
                .args(["ps"])
                .current_dir("server")
                .output()?;

            if String::from_utf8_lossy(&output.stdout).contains("postgres") {
                print_success("PostgreSQL container is running");
            } else {
                print_warning("PostgreSQL container is not running");
            }
        }
    }
    Ok(())
}

fn handle_build_command(cmd: BuildCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        BuildCommands::Shared => {
            print_step("Building shared code");
            run_command("cargo", &["build", "--package", "shared"], None)?;
            print_success("Shared code built");
        }
        BuildCommands::Server => {
            print_step("Building server");
            run_command("cargo", &["build", "--package", "server"], None)?;
            print_success("Server built");
        }
        BuildCommands::Ios => {
            print_step("Building iOS app");
            run_command("bash", &["./build-and-run.sh", "--build-only"], Some("iOS"))?;
            print_success("iOS app built");
        }
        BuildCommands::All => {
            handle_build_command(BuildCommands::Shared)?;
            handle_build_command(BuildCommands::Server)?;
            handle_build_command(BuildCommands::Ios)?;
        }
        BuildCommands::Types => {
            print_step("Generating type bindings");
            generate_type_bindings()?;
            print_success("Type bindings generated");
        }
        BuildCommands::Full => {
            print_step("Running full build with type generation");
            full_build_with_typegen()?;
            print_success("Full build completed");
        }
        BuildCommands::Core => {
            print_step("Building and testing Crux core");
            build_and_test_core()?;
            print_success("Crux core build and test completed");
        }
        BuildCommands::Rebuild => {
            print_step("Clean rebuilding all components");
            clean_rebuild_all()?;
            print_success("Clean rebuild completed");
        }
    }
    Ok(())
}

fn handle_dev_command(cmd: DevCommands) -> Result<()> {
    match cmd {
        DevCommands::Start => handle_start(false),
        DevCommands::Quick => handle_quick(false),
        DevCommands::Stop => {
            print_step("Stopping development services");
            // Kill server processes
            let _ = Command::new("pkill").args(["-f", "server"]).output();
            // Stop Docker containers
            let _ = Command::new("docker-compose")
                .args(["down"])
                .current_dir("server")
                .output();
            print_success("Development services stopped");
            Ok(())
        }
        DevCommands::Status => {
            print_step("Checking development status");

            // Check server status
            let server_running = Command::new("lsof")
                .args(["-ti:3000"])
                .output()
                .map(|o| !o.stdout.is_empty())
                .unwrap_or(false);

            if server_running {
                print_success("Server is running on port 3000");
            } else {
                print_warning("Server is not running");
            }

            // Check PostgreSQL status
            let pg_running = Command::new("docker-compose")
                .args(["ps"])
                .current_dir("server")
                .output()
                .map(|o| String::from_utf8_lossy(&o.stdout).contains("postgres"))
                .unwrap_or(false);

            if pg_running {
                print_success("PostgreSQL is running");
            } else {
                print_warning("PostgreSQL is not running");
            }

            Ok(())
        }
    }
}

fn handle_server_command(cmd: ServerCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        ServerCommands::Build => {
            print_step("Building server");
            run_command("cargo", &["build", "--package", "server"], None)?;
            print_success("Server built");
        }
        ServerCommands::Run => {
            print_step("Starting server");
            run_command("cargo", &["run", "--package", "server"], None)?;
        }
        ServerCommands::Start => {
            print_step("Building and starting server");
            build_and_run_server()?;
        }
        ServerCommands::Rebuild => {
            print_step("Rebuilding and starting server");
            rebuild_and_run_server()?;
        }
        ServerCommands::Stop => {
            print_step("Stopping server");
            let _ = Command::new("pkill").args(["-f", "server"]).output();
            print_success("Server stopped");
        }
        ServerCommands::Logs => {
            print_step("Showing server logs");
            run_command("tail", &["-f", "server.log"], None)?;
        }
        ServerCommands::Status => {
            let server_running = Command::new("lsof")
                .args(["-ti:3000"])
                .output()
                .map(|o| !o.stdout.is_empty())
                .unwrap_or(false);

            if server_running {
                print_success("Server is running on port 3000");
            } else {
                print_warning("Server is not running");
            }
        }
    }
    Ok(())
}

fn handle_ios_command(cmd: IosCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        IosCommands::Build => {
            print_step("Building iOS app");
            run_command("xcodegen", &[], Some("iOS"))?;
            run_command(
                "xcodebuild",
                &[
                    "-project",
                    "Intrada.xcodeproj",
                    "-scheme",
                    "Intrada",
                    "-destination",
                    "generic/platform=iOS Simulator",
                    "build",
                ],
                Some("iOS"),
            )?;
            print_success("iOS app built");
        }
        IosCommands::Run => {
            print_step("Running iOS app");
            build_and_run_ios()?;
        }
        IosCommands::Start => {
            print_step("Building and running iOS app");
            build_and_run_ios()?;
        }
        IosCommands::Rebuild => {
            print_step("Rebuilding and running iOS app");
            rebuild_and_run_ios()?;
        }
        IosCommands::Simulators => {
            print_step("Listing available simulators");
            run_command("xcrun", &["simctl", "list", "devices", "available"], None)?;
        }
    }
    Ok(())
}

fn handle_setup() -> Result<()> {
    print_info("🚀 Setting up Intrada development environment");

    ensure_in_project_root()?;

    print_step("Checking Docker");
    ensure_docker_running()?;

    print_step("Starting PostgreSQL");
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(5));

    print_step("Running full build with type generation");
    run_command("bash", &["./build-and-typegen.sh"], None)?;

    print_success("🎉 Setup completed! Run 'intrada start' to begin development");
    Ok(())
}

fn handle_start(with_logs: bool) -> Result<()> {
    print_info("🚀 Starting Intrada development environment");
    if with_logs {
        start_with_logs("./dev-start.sh")?;
    } else {
        run_command("bash", &["./dev-start.sh"], None)?;
    }
    Ok(())
}

fn handle_quick(with_logs: bool) -> Result<()> {
    print_info("⚡ Quick starting Intrada development environment");
    if with_logs {
        start_with_logs("./dev-quick.sh")?;
    } else {
        run_command("bash", &["./dev-quick.sh"], None)?;
    }
    Ok(())
}

fn handle_rebuild(with_logs: bool) -> Result<()> {
    print_info("🔄 Rebuilding and starting Intrada development environment");
    rebuild_and_start(with_logs)?;
    Ok(())
}

fn handle_logs_command(cmd: LogCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        LogCommands::Server => {
            print_step("Streaming server logs");
            stream_server_logs()?;
        }
        LogCommands::Ios => {
            print_step("Streaming iOS simulator logs");
            stream_ios_logs()?;
        }
        LogCommands::Database => {
            print_step("Streaming PostgreSQL logs");
            stream_database_logs()?;
        }
        LogCommands::Docker => {
            print_step("Streaming Docker logs");
            stream_docker_logs()?;
        }
        LogCommands::All => {
            print_step("Streaming all logs (multiplexed)");
            stream_all_logs()?;
        }
    }
    Ok(())
}

fn handle_test_command(cmd: TestCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        TestCommands::Core => {
            print_step("Testing Crux core");
            test_core()?;
            print_success("Core tests completed");
        }
        TestCommands::Server => {
            print_step("Testing server");
            test_server()?;
            print_success("Server tests completed");
        }
        TestCommands::Ios => {
            print_step("Testing iOS app");
            test_ios()?;
            print_success("iOS tests completed");
        }
        TestCommands::Web => {
            print_step("Testing web app");
            test_web()?;
            print_success("Web tests completed");
        }
        TestCommands::All => {
            print_step("Testing all components");
            test_core()?;
            test_server()?;
            test_web()?;
            // iOS tests are more complex and require simulator, so make them optional
            print_info("Skipping iOS tests in 'all' - run 'intrada test ios' separately");
            print_success("All tests completed");
        }
    }
    Ok(())
}

// Utility functions
fn ensure_in_project_root() -> Result<()> {
    if !Path::new("Cargo.toml").exists() || !Path::new("shared").exists() {
        anyhow::bail!("Must be run from the Intrada project root directory");
    }
    Ok(())
}

fn ensure_docker_running() -> Result<()> {
    let output = Command::new("docker")
        .args(["info"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;

    if !output.success() {
        anyhow::bail!("Docker is not running. Please start Docker Desktop and try again.");
    }
    Ok(())
}

fn run_command(cmd: &str, args: &[&str], working_dir: Option<&str>) -> Result<()> {
    let mut command = Command::new(cmd);
    command.args(args);

    if let Some(dir) = working_dir {
        command.current_dir(dir);
    }

    let status = command
        .status()
        .with_context(|| format!("Failed to execute command: {} {}", cmd, args.join(" ")))?;

    if !status.success() {
        anyhow::bail!("Command failed: {} {}", cmd, args.join(" "));
    }

    Ok(())
}

fn print_step(msg: &str) {
    println!("{} {}", "🔄".blue(), msg.blue());
}

fn print_success(msg: &str) {
    println!("{} {}", "✅".green(), msg.green());
}

fn print_warning(msg: &str) {
    println!("{} {}", "⚠️".yellow(), msg.yellow());
}

fn print_info(msg: &str) {
    println!("{} {}", "📋".purple(), msg.purple());
}

// Logging functions
fn start_with_logs(script: &str) -> Result<()> {
    print_info("Starting with log streaming enabled");

    // Start the development script in background
    let mut child = Command::new("bash")
        .arg(script)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to start development script")?;

    // Stream the output
    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(line) => println!("{} {}", "[DEV]".cyan(), line),
                Err(_) => break,
            }
        }
    }

    let _ = child.wait()?;
    Ok(())
}

fn stream_server_logs() -> Result<()> {
    if Path::new("server.log").exists() {
        let mut child = Command::new("tail")
            .args(["-f", "server.log"])
            .stdout(Stdio::piped())
            .spawn()
            .context("Failed to start tail command")?;

        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                match line {
                    Ok(line) => println!("{} {}", "[SERVER]".green(), line),
                    Err(_) => break,
                }
            }
        }

        let _ = child.wait()?;
    } else {
        print_warning("server.log not found. Is the server running?");
        print_info("Try: intrada server start");
    }
    Ok(())
}

fn stream_ios_logs() -> Result<()> {
    // Get the bundle ID for filtering
    let bundle_id = "com.jonyardley.Intrada";

    print_info(&format!("Streaming logs for bundle ID: {bundle_id}"));

    let mut child = Command::new("xcrun")
        .args([
            "simctl",
            "spawn",
            "booted",
            "log",
            "stream",
            "--predicate",
            &format!("subsystem CONTAINS '{bundle_id}'"),
        ])
        .stdout(Stdio::piped())
        .spawn()
        .context("Failed to start iOS log stream")?;

    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(line) => println!("{} {}", "[iOS]".blue(), line),
                Err(_) => break,
            }
        }
    }

    let _ = child.wait()?;
    Ok(())
}

fn stream_database_logs() -> Result<()> {
    let mut child = Command::new("docker-compose")
        .args(["logs", "-f", "postgres"])
        .current_dir("server")
        .stdout(Stdio::piped())
        .spawn()
        .context("Failed to start database log stream")?;

    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(line) => println!("{} {}", "[DB]".yellow(), line),
                Err(_) => break,
            }
        }
    }

    let _ = child.wait()?;
    Ok(())
}

fn stream_docker_logs() -> Result<()> {
    let mut child = Command::new("docker-compose")
        .args(["logs", "-f"])
        .current_dir("server")
        .stdout(Stdio::piped())
        .spawn()
        .context("Failed to start Docker log stream")?;

    if let Some(stdout) = child.stdout.take() {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(line) => println!("{} {}", "[DOCKER]".magenta(), line),
                Err(_) => break,
            }
        }
    }

    let _ = child.wait()?;
    Ok(())
}

fn stream_all_logs() -> Result<()> {
    print_info("Starting multiplexed log streaming");
    print_info("Press Ctrl+C to stop");

    // Start multiple log streams in separate threads
    let handles = vec![
        thread::spawn(|| {
            if Path::new("server.log").exists() {
                let _ = stream_server_logs();
            }
        }),
        thread::spawn(|| {
            let _ = stream_database_logs();
        }),
        thread::spawn(|| {
            let _ = stream_ios_logs();
        }),
    ];

    // Wait for all threads (they run indefinitely until Ctrl+C)
    for handle in handles {
        let _ = handle.join();
    }

    Ok(())
}

// Platform-specific build and run functions
fn build_and_run_server() -> Result<()> {
    ensure_in_project_root()?;

    // Check for and kill existing server processes
    if let Ok(output) = Command::new("lsof").args(["-ti:3000"]).output() {
        if !output.stdout.is_empty() {
            let pid = String::from_utf8_lossy(&output.stdout).trim().to_string();
            print_step(&format!("Stopping existing server (PID: {pid})"));
            let _ = Command::new("kill").arg(&pid).output();
            thread::sleep(Duration::from_secs(2));
        }
    }

    // Start PostgreSQL
    print_step("Starting PostgreSQL database");
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(3));

    // Build and run server
    print_step("Building and running server");
    run_command("cargo", &["run", "--package", "server"], Some("server"))?;

    Ok(())
}

fn build_and_run_ios() -> Result<()> {
    ensure_in_project_root()?;

    // Generate Xcode project
    print_step("Generating Xcode project");
    run_command("xcodegen", &[], Some("iOS"))?;

    // Get available simulators and use the first iPhone simulator
    print_step("Finding iOS simulator");
    let output = Command::new("xcrun")
        .args(["simctl", "list", "devices", "iPhone", "available"])
        .output()
        .context("Failed to list simulators")?;

    let simulator_output = String::from_utf8_lossy(&output.stdout);
    let simulator_id = simulator_output
        .lines()
        .find(|line| line.contains("iPhone") && line.contains("(") && line.contains(")"))
        .and_then(|line| {
            // Extract UUID from parentheses
            line.split('(').nth(1)?.split(')').next()
        })
        .unwrap_or("booted")
        .to_string();

    print_info(&format!("Using simulator: {simulator_id}"));

    // Build the app
    print_step("Building iOS app");
    run_command(
        "xcodebuild",
        &[
            "-project",
            "Intrada.xcodeproj",
            "-scheme",
            "Intrada",
            "-destination",
            &format!("id={simulator_id}"),
            "build",
        ],
        Some("iOS"),
    )?;

    // Install and launch the app
    print_step("Installing and launching iOS app");
    let bundle_id = "com.jonyardley.Intrada";

    // Boot simulator if needed
    let _ = Command::new("xcrun")
        .args(["simctl", "boot", &simulator_id])
        .output();

    // Install app (assuming build output location)
    let _ = Command::new("xcrun")
        .args([
            "simctl",
            "install",
            &simulator_id,
            "build/Release-iphonesimulator/Intrada.app",
        ])
        .current_dir("iOS")
        .output();

    // Launch app
    run_command(
        "xcrun",
        &["simctl", "launch", &simulator_id, bundle_id],
        None,
    )?;

    print_success("iOS app launched successfully");
    Ok(())
}

fn generate_type_bindings() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🔄 Generating type bindings for iOS...");

    // Step 1: Generate FFI bindings (uniffi) - provides CoreFFI interface for iOS
    print_step("📦 Generating FFI bindings (Shared package)...");
    run_command(
        "cargo",
        &["swift", "package", "--name", "Shared", "--platforms", "ios"],
        Some("shared"),
    )?;

    // Clean up generated files
    let generated_path = Path::new("shared/generated");
    if generated_path.exists() {
        let _ = std::fs::remove_file("shared/generated/headers");
        let _ = std::fs::remove_file("shared/generated/sources");
        let _ = std::fs::remove_dir_all("shared/generated");
    }

    // Step 2: Generate data types (facet) - provides SharedTypes for iOS
    print_step("🏗️  Generating data types (SharedTypes package)...");
    run_command("cargo", &["build"], Some("shared_types"))?;

    // Step 3: Generate core app bindings (crux_cli) - provides event/effect types
    print_step("⚙️  Generating core bindings...");
    run_command(
        "cargo",
        &[
            "run",
            "--package",
            "shared",
            "--bin",
            "crux_cli",
            "--features",
            "cli",
            "--",
            "bindgen",
            "--crate-name",
            "shared",
        ],
        None,
    )?;

    print_success("✅ Type generation complete!");
    print_info("📁 Generated files:");
    print_info("   - shared/Shared/ (FFI bindings)");
    print_info("   - shared_types/generated/swift/ (Data types)");
    print_info("   - shared/generated/ (Core bindings)");

    Ok(())
}

fn full_build_with_typegen() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🏗️  Building Intrada project...");

    // Step 1: Generate Xcode project
    print_step("📱 Generating Xcode project...");
    run_command("xcodegen", &[], Some("iOS"))?;

    // Step 2: Build shared crate
    print_step("🦀 Building shared crate...");
    run_command(
        "cargo",
        &["build", "--manifest-path", "shared/Cargo.toml"],
        None,
    )?;

    // Step 3: Build shared_types crate
    print_step("🔧 Building shared_types crate...");
    run_command(
        "cargo",
        &["build", "--manifest-path", "shared_types/Cargo.toml"],
        None,
    )?;

    // Step 4: Run type generation
    print_step("🔄 Running type generation...");
    generate_type_bindings()?;

    print_success("✅ Build and type generation complete!");
    print_success("🎉 Ready for development!");

    Ok(())
}

fn build_and_test_core() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🦀 Building and testing Crux core...");

    // Step 1: Build the shared core
    print_step("🔨 Building shared core");
    run_command("cargo", &["build", "--package", "shared"], None)?;

    // Step 2: Run clippy on the core
    print_step("🔍 Running clippy on shared core");
    run_command(
        "cargo",
        &[
            "clippy",
            "--package",
            "shared",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ],
        None,
    )?;

    // Step 3: Format check
    print_step("🎨 Checking formatting");
    run_command("cargo", &["fmt", "--package", "shared", "--check"], None)?;

    // Step 4: Run tests
    print_step("🧪 Running core tests");
    run_command("cargo", &["test", "--package", "shared"], None)?;

    // Step 5: Run tests with nextest if available (faster)
    print_step("⚡ Running tests with nextest (if available)");
    let nextest_result = Command::new("cargo")
        .args(["nextest", "run", "--package", "shared"])
        .status();

    match nextest_result {
        Ok(status) if status.success() => {
            print_success("Nextest completed successfully");
        }
        Ok(_) => {
            print_warning("Nextest failed, but regular tests passed");
        }
        Err(_) => {
            print_info("Nextest not available, using regular cargo test");
        }
    }

    // Step 6: Check documentation
    print_step("📚 Checking documentation");
    run_command(
        "cargo",
        &[
            "doc",
            "--package",
            "shared",
            "--no-deps",
            "--document-private-items",
        ],
        None,
    )?;

    // Step 7: Build with different feature flags
    print_step("🎯 Testing feature flags");
    run_command(
        "cargo",
        &["build", "--package", "shared", "--no-default-features"],
        None,
    )?;
    run_command(
        "cargo",
        &["build", "--package", "shared", "--all-features"],
        None,
    )?;

    print_success("✅ Core build and test complete!");
    print_info("📋 Core validation summary:");
    print_info("   ✅ Build successful");
    print_info("   ✅ Clippy passed");
    print_info("   ✅ Format check passed");
    print_info("   ✅ Tests passed");
    print_info("   ✅ Documentation built");
    print_info("   ✅ Feature flags tested");

    Ok(())
}

// Test functions for each component
fn test_core() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🧪 Testing Crux core...");

    // Run core tests with verbose output
    print_step("Running shared package tests");
    run_command("cargo", &["test", "--package", "shared", "--verbose"], None)?;

    // Run with nextest if available
    print_step("Running tests with nextest (if available)");
    let nextest_result = Command::new("cargo")
        .args(["nextest", "run", "--package", "shared", "--verbose"])
        .status();

    match nextest_result {
        Ok(status) if status.success() => {
            print_success("Nextest completed successfully");
        }
        Ok(_) => {
            print_warning("Nextest failed, but regular tests passed");
        }
        Err(_) => {
            print_info("Nextest not available, using regular cargo test");
        }
    }

    print_success("✅ Core tests passed!");
    Ok(())
}

fn test_server() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🖥️ Testing server...");

    // Build server first
    print_step("Building server");
    run_command("cargo", &["build", "--package", "server"], None)?;

    // Run server tests
    print_step("Running server tests");
    run_command("cargo", &["test", "--package", "server", "--verbose"], None)?;

    // Run clippy on server
    print_step("Running clippy on server");
    run_command(
        "cargo",
        &[
            "clippy",
            "--package",
            "server",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ],
        None,
    )?;

    // Check if we can start the server (basic smoke test)
    print_step("Running server smoke test");
    print_info("Starting PostgreSQL for server test");
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(3));

    // Try to build and check server compiles
    print_step("Verifying server compilation");
    run_command("cargo", &["check", "--package", "server"], None)?;

    print_success("✅ Server tests passed!");
    Ok(())
}

fn test_web() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🌐 Testing web app...");

    if !Path::new("web-leptos").exists() {
        print_warning("Web app directory not found, skipping web tests");
        return Ok(());
    }

    // Build web app
    print_step("Building web app");
    run_command("cargo", &["build"], Some("web-leptos"))?;

    // Run web app tests
    print_step("Running web app tests");
    run_command("cargo", &["test", "--verbose"], Some("web-leptos"))?;

    // Check web app with clippy
    print_step("Running clippy on web app");
    run_command(
        "cargo",
        &[
            "clippy",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ],
        Some("web-leptos"),
    )?;

    // Check if npm dependencies are up to date
    if Path::new("web-leptos/package.json").exists() {
        print_step("Checking npm dependencies");
        run_command(
            "npm",
            &["audit", "--audit-level", "moderate"],
            Some("web-leptos"),
        )?;
    }

    print_success("✅ Web tests passed!");
    Ok(())
}

fn test_ios() -> Result<()> {
    ensure_in_project_root()?;

    print_info("📱 Testing iOS app...");

    if !Path::new("iOS").exists() {
        print_warning("iOS directory not found, skipping iOS tests");
        return Ok(());
    }

    // Generate Xcode project first
    print_step("Generating Xcode project");
    run_command("xcodegen", &[], Some("iOS"))?;

    // Build iOS app for testing
    print_step("Building iOS app for testing");
    run_command(
        "xcodebuild",
        &[
            "-project",
            "Intrada.xcodeproj",
            "-scheme",
            "Intrada",
            "-destination",
            "platform=iOS Simulator,name=iPhone 15",
            "build-for-testing",
        ],
        Some("iOS"),
    )?;

    // Run iOS tests
    print_step("Running iOS tests");
    run_command(
        "xcodebuild",
        &[
            "-project",
            "Intrada.xcodeproj",
            "-scheme",
            "Intrada",
            "-destination",
            "platform=iOS Simulator,name=iPhone 15",
            "test-without-building",
        ],
        Some("iOS"),
    )?;

    // Check Swift code formatting (if swiftformat is available)
    print_step("Checking Swift formatting (if available)");
    let swiftformat_result = Command::new("swiftformat")
        .args(["--lint", "."])
        .current_dir("iOS")
        .status();

    match swiftformat_result {
        Ok(status) if status.success() => {
            print_success("Swift formatting check passed");
        }
        Ok(_) => {
            print_warning("Swift formatting issues found");
        }
        Err(_) => {
            print_info("SwiftFormat not available, skipping formatting check");
        }
    }

    print_success("✅ iOS tests passed!");
    Ok(())
}

fn rebuild_and_start(with_logs: bool) -> Result<()> {
    ensure_in_project_root()?;

    print_info("🔄 Rebuilding Intrada development environment...");

    // Step 1: Stop all existing services
    print_step("🛑 Stopping existing services");
    let _ = Command::new("pkill").args(["-f", "server"]).output();
    let _ = Command::new("docker-compose")
        .args(["down"])
        .current_dir("server")
        .output();

    // Give services time to stop
    thread::sleep(Duration::from_secs(2));

    // Step 2: Clean build artifacts
    print_step("🧹 Cleaning build artifacts");
    run_command("cargo", &["clean"], None)?;

    // Clean iOS derived data if it exists
    if Path::new("iOS").exists() {
        let _ = Command::new("rm")
            .args(["-rf", "~/Library/Developer/Xcode/DerivedData"])
            .output();
    }

    // Step 3: Full build with type generation
    print_step("🏗️  Full rebuild with type generation");
    full_build_with_typegen()?;

    // Step 4: Start development environment
    print_step("🚀 Starting development environment");

    if with_logs {
        print_info("Starting with live log streaming");
        start_development_with_logs()?;
    } else {
        start_development_environment()?;
    }

    print_success("🎉 Rebuild and start completed!");
    Ok(())
}

fn start_development_environment() -> Result<()> {
    ensure_in_project_root()?;

    // Start PostgreSQL
    print_step("Starting PostgreSQL database");
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(3));

    // Start server in background
    print_step("Starting server");
    let mut server_cmd = Command::new("cargo")
        .args(["run", "--package", "server"])
        .current_dir("server")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to start server")?;

    // Give server time to start
    thread::sleep(Duration::from_secs(3));

    // Check if server is still running
    match server_cmd.try_wait() {
        Ok(Some(status)) => {
            anyhow::bail!("Server exited unexpectedly with status: {}", status);
        }
        Ok(None) => {
            print_success("Server started successfully");
        }
        Err(e) => {
            anyhow::bail!("Failed to check server status: {}", e);
        }
    }

    // Build and launch iOS app
    print_step("Building and launching iOS app");
    build_and_run_ios()?;

    print_info("Development environment is running!");
    print_info("📋 To stop services: intrada dev stop");
    print_info("📋 To view logs: intrada logs all");

    Ok(())
}

fn start_development_with_logs() -> Result<()> {
    ensure_in_project_root()?;

    print_info("Starting development environment with live log streaming");

    // Start PostgreSQL
    print_step("Starting PostgreSQL database");
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(3));

    // Start server and stream logs
    print_step("Starting server with log streaming");
    let mut server_cmd = Command::new("cargo")
        .args(["run", "--package", "server"])
        .current_dir("server")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to start server")?;

    // Stream server logs in a separate thread
    if let Some(stdout) = server_cmd.stdout.take() {
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                match line {
                    Ok(line) => println!("{} {}", "[SERVER]".green(), line),
                    Err(_) => break,
                }
            }
        });
    }

    // Give server time to start
    thread::sleep(Duration::from_secs(5));

    // Build and launch iOS app
    print_step("Building and launching iOS app");
    build_and_run_ios()?;

    // Start log streaming
    print_info("🔄 Starting log streaming - Press Ctrl+C to stop");
    stream_all_logs()?;

    Ok(())
}

// Component-specific rebuild functions
fn clean_rebuild_all() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🧹 Clean rebuilding all components...");

    // Step 1: Clean all build artifacts
    print_step("Cleaning build artifacts");
    run_command("cargo", &["clean"], None)?;

    // Clean iOS derived data if it exists
    if Path::new("iOS").exists() {
        let _ = Command::new("rm")
            .args(["-rf", "~/Library/Developer/Xcode/DerivedData"])
            .output();
    }

    // Step 2: Rebuild shared components
    print_step("Rebuilding shared code");
    run_command("cargo", &["build", "--package", "shared"], None)?;

    // Step 3: Rebuild server
    print_step("Rebuilding server");
    run_command("cargo", &["build", "--package", "server"], None)?;

    // Step 4: Rebuild iOS (generate project and build)
    if Path::new("iOS").exists() {
        print_step("Rebuilding iOS app");
        run_command("xcodegen", &[], Some("iOS"))?;
        run_command(
            "xcodebuild",
            &[
                "-project",
                "Intrada.xcodeproj",
                "-scheme",
                "Intrada",
                "-destination",
                "generic/platform=iOS Simulator",
                "build",
            ],
            Some("iOS"),
        )?;
    }

    // Step 5: Rebuild web app if it exists
    if Path::new("web-leptos").exists() {
        print_step("Rebuilding web app");
        run_command("cargo", &["build"], Some("web-leptos"))?;
    }

    // Step 6: Regenerate type bindings
    print_step("Regenerating type bindings");
    generate_type_bindings()?;

    print_success("✅ All components rebuilt successfully!");
    Ok(())
}

fn rebuild_and_run_server() -> Result<()> {
    ensure_in_project_root()?;

    print_info("🔄 Rebuilding and starting server...");

    // Step 1: Stop existing server
    print_step("Stopping existing server");
    let _ = Command::new("pkill").args(["-f", "server"]).output();
    thread::sleep(Duration::from_secs(2));

    // Step 2: Clean server build artifacts
    print_step("Cleaning server build artifacts");
    run_command("cargo", &["clean", "--package", "server"], None)?;

    // Step 3: Stop and restart PostgreSQL
    print_step("Restarting PostgreSQL database");
    let _ = Command::new("docker-compose")
        .args(["down"])
        .current_dir("server")
        .output();
    run_command("docker-compose", &["up", "-d"], Some("server"))?;
    thread::sleep(Duration::from_secs(3));

    // Step 4: Rebuild and start server
    print_step("Rebuilding and starting server");
    run_command("cargo", &["run", "--package", "server"], Some("server"))?;

    print_success("✅ Server rebuilt and started!");
    Ok(())
}

fn rebuild_and_run_ios() -> Result<()> {
    ensure_in_project_root()?;

    print_info("📱 Rebuilding and running iOS app...");

    if !Path::new("iOS").exists() {
        print_warning("iOS directory not found, skipping iOS rebuild");
        return Ok(());
    }

    // Step 1: Clean iOS build artifacts
    print_step("Cleaning iOS build artifacts");
    let _ = Command::new("rm")
        .args(["-rf", "~/Library/Developer/Xcode/DerivedData"])
        .output();

    // Clean iOS build directory
    let _ = Command::new("rm")
        .args(["-rf", "build"])
        .current_dir("iOS")
        .output();

    // Step 2: Rebuild shared dependencies
    print_step("Rebuilding shared dependencies");
    run_command("cargo", &["build", "--package", "shared"], None)?;

    // Step 3: Regenerate type bindings
    print_step("Regenerating type bindings");
    generate_type_bindings()?;

    // Step 4: Generate fresh Xcode project
    print_step("Generating fresh Xcode project");
    run_command("xcodegen", &[], Some("iOS"))?;

    // Step 5: Build and run iOS app
    print_step("Building and running iOS app");
    build_and_run_ios()?;

    print_success("✅ iOS app rebuilt and started!");
    Ok(())
}

fn handle_clean_command(cmd: CleanCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        CleanCommands::All => {
            print_step("Cleaning all build artifacts");
            clean_shared()?;
            clean_server()?;
            clean_ios()?;
            clean_web()?;
            print_success("✅ All build artifacts cleaned!");
        }
        CleanCommands::Shared => {
            print_step("Cleaning shared Rust artifacts");
            clean_shared()?;
            print_success("✅ Shared artifacts cleaned!");
        }
        CleanCommands::Server => {
            print_step("Cleaning server build artifacts");
            clean_server()?;
            print_success("✅ Server artifacts cleaned!");
        }
        CleanCommands::Ios => {
            print_step("Cleaning iOS build artifacts and derived data");
            clean_ios()?;
            print_success("✅ iOS artifacts cleaned!");
        }
        CleanCommands::Web => {
            print_step("Cleaning web build artifacts");
            clean_web()?;
            print_success("✅ Web artifacts cleaned!");
        }
    }
    Ok(())
}

fn clean_shared() -> Result<()> {
    run_command("cargo", &["clean", "--package", "shared"], None)?;
    run_command("cargo", &["clean", "--package", "shared_types"], None)?;
    Ok(())
}

fn clean_server() -> Result<()> {
    run_command("cargo", &["clean", "--package", "server"], None)?;
    Ok(())
}

fn clean_ios() -> Result<()> {
    if Path::new("iOS").exists() {
        // Clean Xcode derived data
        run_command(
            "rm",
            &["-rf", "~/Library/Developer/Xcode/DerivedData"],
            None,
        )
        .ok();

        // Clean iOS build directory
        if Path::new("iOS/build").exists() {
            run_command("rm", &["-rf", "iOS/build"], None)?;
        }

        // Clean generated bindings
        if Path::new("iOS/Intrada/core.swift").exists() {
            run_command("rm", &["-f", "iOS/Intrada/core.swift"], None)?;
        }
    }
    Ok(())
}

fn clean_web() -> Result<()> {
    if Path::new("web-leptos").exists() {
        run_command("cargo", &["clean", "--package", "web-leptos"], None)?;

        // Clean npm artifacts if they exist
        if Path::new("web-leptos/node_modules").exists() {
            run_command("rm", &["-rf", "web-leptos/node_modules"], None)?;
        }
        if Path::new("web-leptos/dist").exists() {
            run_command("rm", &["-rf", "web-leptos/dist"], None)?;
        }
    }
    Ok(())
}

fn handle_watch() -> Result<()> {
    ensure_in_project_root()?;

    print_step("Starting file watcher for automatic rebuilds");
    print_info("💡 This will watch for changes and rebuild automatically");
    print_info("   Press Ctrl+C to stop watching");

    // Use cargo-watch if available, otherwise provide instructions
    let output = Command::new("cargo").args(["watch", "--version"]).output();

    if output.is_ok() {
        print_step("Running cargo watch on shared code");
        run_command("cargo", &["watch", "-w", "shared/src", "-x", "build"], None)?;
    } else {
        print_warning("⚠️  cargo-watch not installed. Install it with:");
        println!("   cargo install cargo-watch");
        println!();
        print_info("💡 Alternative: Use your editor's file watcher or run builds manually");
    }

    Ok(())
}

fn handle_format() -> Result<()> {
    ensure_in_project_root()?;

    print_step("Formatting all code");

    // Format Rust code
    print_info("Formatting Rust code...");
    run_command("cargo", &["fmt", "--all"], None)?;

    // Format Swift code if swiftformat is available
    if Path::new("iOS").exists() {
        let output = Command::new("swiftformat").args(["--version"]).output();

        if output.is_ok() {
            print_info("Formatting Swift code...");
            run_command(
                "swiftformat",
                &["iOS/Intrada", "--swiftversion", "5.9"],
                None,
            )?;
        } else {
            print_warning("⚠️  swiftformat not installed. Swift code not formatted.");
            print_info("   Install with: brew install swiftformat");
        }
    }

    // Format web code if prettier is available
    if Path::new("web-leptos").exists() {
        let output = Command::new("npx")
            .args(["prettier", "--version"])
            .current_dir("web-leptos")
            .output();

        if output.is_ok() {
            print_info("Formatting web code...");
            run_command(
                "npx",
                &["prettier", "--write", "src/**/*.{js,ts,css,html}"],
                Some("web-leptos"),
            )?;
        }
    }

    print_success("✅ All code formatted!");
    Ok(())
}

fn handle_lint() -> Result<()> {
    ensure_in_project_root()?;

    print_step("Running linters");

    // Lint Rust code
    print_info("Linting Rust code...");
    run_command(
        "cargo",
        &[
            "clippy",
            "--workspace",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ],
        None,
    )?;

    // Check Rust formatting
    print_info("Checking Rust formatting...");
    run_command("cargo", &["fmt", "--all", "--check"], None)?;

    // Lint Swift code if SwiftLint is available
    if Path::new("iOS").exists() {
        let output = Command::new("swiftlint").args(["version"]).output();

        if output.is_ok() {
            print_info("Linting Swift code...");
            run_command("swiftlint", &["lint", "iOS/Intrada"], None)?;
        } else {
            print_warning("⚠️  SwiftLint not installed. Swift code not linted.");
            print_info("   Install with: brew install swiftlint");
        }
    }

    print_success("✅ All linting passed!");
    Ok(())
}

fn handle_deps_command(cmd: DepsCommands) -> Result<()> {
    ensure_in_project_root()?;

    match cmd {
        DepsCommands::Check => {
            print_step("Checking for outdated dependencies");

            // Check Rust dependencies
            print_info("Checking Rust dependencies...");
            let output = Command::new("cargo")
                .args(["outdated", "--version"])
                .output();

            if output.is_ok() {
                run_command("cargo", &["outdated"], None)?;
            } else {
                print_warning("⚠️  cargo-outdated not installed. Install with:");
                println!("   cargo install cargo-outdated");
                println!();
                print_info("💡 Alternative: Check Cargo.toml files manually");
            }

            // Check npm dependencies if web project exists
            if Path::new("web-leptos/package.json").exists() {
                print_info("Checking npm dependencies...");
                run_command("npm", &["outdated"], Some("web-leptos")).ok(); // Don't fail on outdated deps
            }

            print_success("✅ Dependency check complete!");
        }
        DepsCommands::Update => {
            print_step("Updating dependencies");

            // Update Rust dependencies
            print_info("Updating Rust dependencies...");
            run_command("cargo", &["update"], None)?;

            // Update npm dependencies if web project exists
            if Path::new("web-leptos/package.json").exists() {
                print_info("Updating npm dependencies...");
                run_command("npm", &["update"], Some("web-leptos"))?;
            }

            print_success("✅ Dependencies updated!");
        }
    }
    Ok(())
}

fn handle_bench() -> Result<()> {
    ensure_in_project_root()?;

    print_step("Running benchmarks");

    // Run Rust benchmarks
    print_info("Running Rust benchmarks...");
    run_command("cargo", &["bench", "--workspace"], None)?;

    print_success("✅ Benchmarks complete!");
    Ok(())
}

fn handle_doctor() -> Result<()> {
    ensure_in_project_root()?;

    print_step("Running development environment health check");

    let mut issues = Vec::<String>::new();

    // Check Rust installation
    print_info("Checking Rust installation...");
    match Command::new("rustc").args(["--version"]).output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("  ✅ Rust: {}", version.trim());
        }
        Err(_) => {
            issues.push("❌ Rust not found. Install from https://rustup.rs/".to_string());
        }
    }

    // Check Cargo
    match Command::new("cargo").args(["--version"]).output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("  ✅ Cargo: {}", version.trim());
        }
        Err(_) => {
            issues.push("❌ Cargo not found".to_string());
        }
    }

    // Check Docker
    print_info("Checking Docker...");
    match Command::new("docker").args(["--version"]).output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("  ✅ Docker: {}", version.trim());
        }
        Err(_) => {
            issues.push("❌ Docker not found. Install from https://docker.com/".to_string());
        }
    }

    // Check Docker Compose
    match Command::new("docker-compose").args(["--version"]).output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("  ✅ Docker Compose: {}", version.trim());
        }
        Err(_) => {
            issues.push("❌ Docker Compose not found".to_string());
        }
    }

    // Check Node.js
    print_info("Checking Node.js...");
    match Command::new("node").args(["--version"]).output() {
        Ok(output) => {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("  ✅ Node.js: {}", version.trim());
        }
        Err(_) => {
            issues.push("❌ Node.js not found. Install from https://nodejs.org/".to_string());
        }
    }

    // Check Xcode (macOS only)
    if cfg!(target_os = "macos") {
        print_info("Checking Xcode...");
        match Command::new("xcodebuild").args(["-version"]).output() {
            Ok(output) => {
                let version = String::from_utf8_lossy(&output.stdout);
                println!(
                    "  ✅ Xcode: {}",
                    version.lines().next().unwrap_or("Unknown")
                );
            }
            Err(_) => {
                issues.push("❌ Xcode not found. Install from App Store".to_string());
            }
        }

        // Check XcodeGen
        match Command::new("xcodegen").args(["--version"]).output() {
            Ok(output) => {
                let version = String::from_utf8_lossy(&output.stdout);
                println!("  ✅ XcodeGen: {}", version.trim());
            }
            Err(_) => {
                issues
                    .push("❌ XcodeGen not found. Install with: brew install xcodegen".to_string());
            }
        }
    }

    // Check project structure
    print_info("Checking project structure...");
    let required_dirs = ["shared", "server", "xtask"];
    for dir in required_dirs {
        if Path::new(dir).exists() {
            println!("  ✅ {dir}/");
        } else {
            issues.push(format!("❌ Missing directory: {dir}/"));
        }
    }

    // Check database connection
    print_info("Checking database connection...");
    ensure_docker_running()?;
    match run_command("docker-compose", &["ps"], Some("server")) {
        Ok(_) => {
            println!("  ✅ Database container accessible");
        }
        Err(_) => {
            issues.push("⚠️  Database container not running. Run: cargo xtask start".to_string());
        }
    }

    // Summary
    println!();
    if issues.is_empty() {
        print_success("🎉 Development environment is healthy!");
        println!();
        print_info("Ready to run:");
        println!("  cargo xtask setup    # First-time setup");
        println!("  cargo xtask start    # Start development");
    } else {
        print_warning(&format!("⚠️  Found {} issue(s):", issues.len()));
        for issue in issues {
            println!("  {issue}");
        }
        println!();
        print_info("💡 Fix the issues above and run 'cargo xtask doctor' again");
    }

    Ok(())
}
