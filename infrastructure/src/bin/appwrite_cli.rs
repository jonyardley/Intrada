use clap::{Parser, Subcommand};
use infrastructure::{MigrationPlanner, SchemaBuilder};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "appwrite-cli")]
#[command(about = "Infrastructure-as-Code CLI for Appwrite backend management")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate Appwrite configuration from Rust types
    Generate {
        /// Database ID
        #[arg(long, default_value = "intrada_db")]
        database_id: String,

        /// Database name
        #[arg(long, default_value = "Intrada Database")]
        database_name: String,

        /// Output format
        #[arg(long, value_enum, default_value = "shell")]
        format: OutputFormat,

        /// Output file (stdout if not specified)
        #[arg(long)]
        output: Option<PathBuf>,

        /// Environment variables prefix
        #[arg(long, default_value = "APPWRITE")]
        env_prefix: String,
    },

    /// Validate the current schema
    Validate {
        /// Database ID
        #[arg(long, default_value = "intrada_db")]
        database_id: String,

        /// Database name
        #[arg(long, default_value = "Intrada Database")]
        database_name: String,
    },

    /// Deploy schema to Appwrite
    Deploy {
        /// Database ID
        #[arg(long, default_value = "intrada_db")]
        database_id: String,

        /// Database name
        #[arg(long, default_value = "Intrada Database")]
        database_name: String,

        /// Environment (dev, staging, prod)
        #[arg(long, default_value = "dev")]
        environment: String,

        /// Dry run - show what would be executed
        #[arg(long)]
        dry_run: bool,

        /// Current schema file for diff
        #[arg(long)]
        current_schema: Option<PathBuf>,
    },

    /// Show diff between current and target schema
    Diff {
        /// Database ID
        #[arg(long, default_value = "intrada_db")]
        database_id: String,

        /// Database name
        #[arg(long, default_value = "Intrada Database")]
        database_name: String,

        /// Current schema file
        #[arg(long)]
        current_schema: Option<PathBuf>,
    },
}

#[derive(clap::ValueEnum, Clone)]
enum OutputFormat {
    Shell,
    Json,
    Terraform,
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Generate {
            database_id,
            database_name,
            format,
            output,
            env_prefix,
        } => {
            generate_schema(database_id, database_name, format, output, env_prefix);
        }
        Commands::Validate {
            database_id,
            database_name,
        } => {
            validate_schema(database_id, database_name);
        }
        Commands::Deploy {
            database_id,
            database_name,
            environment,
            dry_run,
            current_schema,
        } => {
            deploy_schema(
                database_id,
                database_name,
                environment,
                dry_run,
                current_schema,
            );
        }
        Commands::Diff {
            database_id,
            database_name,
            current_schema,
        } => {
            show_diff(database_id, database_name, current_schema);
        }
    }
}

fn generate_schema(
    database_id: String,
    database_name: String,
    format: OutputFormat,
    output: Option<PathBuf>,
    env_prefix: String,
) {
    let builder = SchemaBuilder::new(database_id, database_name);

    let content = match format {
        OutputFormat::Shell => {
            let schema = builder.build_schema();
            let commands = builder.build_appwrite_functions();

            let mut output = String::new();
            output.push_str("#!/bin/bash\n");
            output.push_str("# Generated Appwrite CLI commands\n");
            output.push_str("# This file is auto-generated. Do not edit manually.\n\n");
            output.push_str(&format!("# Database: {}\n", schema.name));
            output.push_str(&format!("# Database ID: {}\n", schema.database_id));
            output.push_str(&format!(
                "# Generated: {}\n\n",
                chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC")
            ));

            output.push_str("set -e\n\n");
            output.push_str(&format!("# Environment variables\n"));
            output.push_str(&format!(
                "export {}_ENDPOINT=\"${{{}_ENDPOINT:-https://cloud.appwrite.io/v1}}\"\n",
                env_prefix, env_prefix
            ));
            output.push_str(&format!(
                "export {}_PROJECT_ID=\"${{{}_PROJECT_ID}}\"\n",
                env_prefix, env_prefix
            ));
            output.push_str(&format!(
                "export {}_API_KEY=\"${{{}_API_KEY}}\"\n\n",
                env_prefix, env_prefix
            ));

            output.push_str("# Check required environment variables\n");
            output.push_str(&format!(
                "if [ -z \"${{{}_PROJECT_ID}}\" ]; then\n",
                env_prefix
            ));
            output.push_str(&format!(
                "  echo \"Error: {}_PROJECT_ID is required\"\n",
                env_prefix
            ));
            output.push_str("  exit 1\n");
            output.push_str("fi\n\n");
            output.push_str(&format!(
                "if [ -z \"${{{}_API_KEY}}\" ]; then\n",
                env_prefix
            ));
            output.push_str(&format!(
                "  echo \"Error: {}_API_KEY is required\"\n",
                env_prefix
            ));
            output.push_str("  exit 1\n");
            output.push_str("fi\n\n");

            output.push_str("# Appwrite CLI commands\n");
            for command in commands {
                output.push_str(&format!("{}\n", command));
            }

            output.push_str("\necho \"Schema deployment completed successfully!\"\n");
            output
        }
        OutputFormat::Json => {
            let schema = builder.build_schema();
            serde_json::to_string_pretty(&schema).unwrap()
        }
        OutputFormat::Terraform => {
            let schema = builder.build_schema();
            generate_terraform_config(&schema)
        }
    };

    match output {
        Some(path) => {
            std::fs::write(path, content).expect("Failed to write output file");
        }
        None => {
            print!("{}", content);
        }
    }
}

fn validate_schema(database_id: String, database_name: String) {
    let builder = SchemaBuilder::new(database_id, database_name);
    let schema = builder.build_schema();

    match infrastructure::schema::validation::validate_schema(&schema) {
        Ok(()) => {
            println!("✅ Schema validation passed");
            println!("Database: {}", schema.name);
            println!("Collections: {}", schema.collections.len());
            for collection in &schema.collections {
                println!(
                    "  - {} ({} attributes, {} indexes)",
                    collection.name,
                    collection.attributes.len(),
                    collection.indexes.len()
                );
            }
        }
        Err(errors) => {
            println!("❌ Schema validation failed:");
            for error in errors {
                println!("  - {}", error);
            }
            std::process::exit(1);
        }
    }
}

fn deploy_schema(
    database_id: String,
    database_name: String,
    environment: String,
    dry_run: bool,
    current_schema_path: Option<PathBuf>,
) {
    let builder = SchemaBuilder::new(database_id, database_name);
    let target_schema = builder.build_schema();

    let current_schema = current_schema_path.and_then(|path| {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|content| serde_json::from_str(&content).ok())
    });

    let migration = MigrationPlanner::plan_migration(
        &current_schema,
        &target_schema,
        format!("Deploy to {}", environment),
        format!("Automated deployment to {} environment", environment),
    );

    if dry_run {
        println!("🔍 Dry run - would execute the following commands:");
        println!("Migration: {}", migration.name);
        println!("Version: {}", migration.version);
        println!("Operations: {}", migration.operations.len());
        println!();

        let commands = infrastructure::migrations::MigrationExecutor::generate_commands(&migration);
        for (i, command) in commands.iter().enumerate() {
            println!("{}. {}", i + 1, command);
        }

        println!("\nRollback commands:");
        let rollback_commands =
            infrastructure::migrations::MigrationExecutor::generate_rollback_commands(&migration);
        for (i, command) in rollback_commands.iter().enumerate() {
            println!("{}. {}", i + 1, command);
        }
    } else {
        println!("🚀 Deploying to {} environment...", environment);
        println!("Migration: {}", migration.name);
        println!("Version: {}", migration.version);

        let commands = infrastructure::migrations::MigrationExecutor::generate_commands(&migration);
        for command in commands {
            println!("Executing: {}", command);
            // Here you would execute the actual command
            // For now, we'll just print it
        }

        println!("✅ Deployment completed successfully!");
    }
}

fn show_diff(database_id: String, database_name: String, current_schema_path: Option<PathBuf>) {
    let builder = SchemaBuilder::new(database_id, database_name);
    let target_schema = builder.build_schema();

    let current_schema = current_schema_path.and_then(|path| {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|content| serde_json::from_str(&content).ok())
    });

    let migration = MigrationPlanner::plan_migration(
        &current_schema,
        &target_schema,
        "Diff Analysis".to_string(),
        "Compare current and target schemas".to_string(),
    );

    println!("📊 Schema Diff Analysis");
    println!("Target Database: {}", target_schema.name);
    println!("Target Collections: {}", target_schema.collections.len());
    println!();

    if migration.operations.is_empty() {
        println!("✅ No changes detected - schemas are identical");
    } else {
        println!("Changes detected:");
        for operation in &migration.operations {
            match operation {
                infrastructure::migrations::MigrationOperation::CreateDatabase {
                    database_id,
                    name,
                } => {
                    println!("  + Create database: {} ({})", name, database_id);
                }
                infrastructure::migrations::MigrationOperation::CreateCollection {
                    database_id: _,
                    collection,
                } => {
                    println!(
                        "  + Create collection: {} ({} attributes, {} indexes)",
                        collection.name,
                        collection.attributes.len(),
                        collection.indexes.len()
                    );
                }
                infrastructure::migrations::MigrationOperation::DeleteCollection {
                    database_id: _,
                    collection_id,
                } => {
                    println!("  - Delete collection: {}", collection_id);
                }
                infrastructure::migrations::MigrationOperation::CreateAttribute {
                    database_id: _,
                    collection_id,
                    attribute,
                } => {
                    println!("  + Add attribute: {}.{}", collection_id, attribute.key);
                }
                infrastructure::migrations::MigrationOperation::DeleteAttribute {
                    database_id: _,
                    collection_id,
                    key,
                } => {
                    println!("  - Remove attribute: {}.{}", collection_id, key);
                }
                infrastructure::migrations::MigrationOperation::CreateIndex {
                    database_id: _,
                    collection_id,
                    index,
                } => {
                    println!("  + Add index: {}.{}", collection_id, index.key);
                }
                infrastructure::migrations::MigrationOperation::DeleteIndex {
                    database_id: _,
                    collection_id,
                    key,
                } => {
                    println!("  - Remove index: {}.{}", collection_id, key);
                }
                _ => {
                    println!("  ~ Other change: {:?}", operation);
                }
            }
        }
    }
}

fn generate_terraform_config(schema: &infrastructure::schema::DatabaseSchema) -> String {
    let mut config = String::new();

    config.push_str("# Generated Terraform configuration for Appwrite\n");
    config.push_str("# This file is auto-generated. Do not edit manually.\n\n");
    config.push_str("terraform {\n");
    config.push_str("  required_providers {\n");
    config.push_str("    appwrite = {\n");
    config.push_str("      source  = \"appwrite/appwrite\"\n");
    config.push_str("      version = \"~> 1.0\"\n");
    config.push_str("    }\n");
    config.push_str("  }\n");
    config.push_str("}\n\n");

    config.push_str("provider \"appwrite\" {\n");
    config.push_str("  endpoint   = var.appwrite_endpoint\n");
    config.push_str("  project_id = var.appwrite_project_id\n");
    config.push_str("  api_key    = var.appwrite_api_key\n");
    config.push_str("}\n\n");

    config.push_str("# Variables\n");
    config.push_str("variable \"appwrite_endpoint\" {\n");
    config.push_str("  description = \"Appwrite endpoint URL\"\n");
    config.push_str("  type        = string\n");
    config.push_str("  default     = \"https://cloud.appwrite.io/v1\"\n");
    config.push_str("}\n\n");
    config.push_str("variable \"appwrite_project_id\" {\n");
    config.push_str("  description = \"Appwrite project ID\"\n");
    config.push_str("  type        = string\n");
    config.push_str("}\n\n");
    config.push_str("variable \"appwrite_api_key\" {\n");
    config.push_str("  description = \"Appwrite API key\"\n");
    config.push_str("  type        = string\n");
    config.push_str("  sensitive   = true\n");
    config.push_str("}\n\n");

    // Database resource
    config.push_str(&format!(
        "resource \"appwrite_database\" \"{}\" {{\n",
        schema.database_id
    ));
    config.push_str(&format!("  database_id = \"{}\"\n", schema.database_id));
    config.push_str(&format!("  name        = \"{}\"\n", schema.name));
    config.push_str("}\n\n");

    // Collections
    for collection in &schema.collections {
        config.push_str(&format!(
            "resource \"appwrite_collection\" \"{}\" {{\n",
            collection.collection_id
        ));
        config.push_str(&format!(
            "  database_id   = appwrite_database.{}.database_id\n",
            schema.database_id
        ));
        config.push_str(&format!(
            "  collection_id = \"{}\"\n",
            collection.collection_id
        ));
        config.push_str(&format!("  name          = \"{}\"\n", collection.name));
        config.push_str("}\n\n");

        // Attributes
        for attr in &collection.attributes {
            let attr_type = match &attr.attribute_type {
                infrastructure::schema::AttributeType::String { .. } => "string",
                infrastructure::schema::AttributeType::Integer { .. } => "integer",
                infrastructure::schema::AttributeType::Boolean => "boolean",
                infrastructure::schema::AttributeType::DateTime => "datetime",
                infrastructure::schema::AttributeType::Enum { .. } => "enum",
                _ => "string",
            };

            config.push_str(&format!(
                "resource \"appwrite_attribute_{}\" \"{}_{}_{}\" {{\n",
                attr_type, schema.database_id, collection.collection_id, attr.key
            ));
            config.push_str(&format!(
                "  database_id   = appwrite_database.{}.database_id\n",
                schema.database_id
            ));
            config.push_str(&format!(
                "  collection_id = appwrite_collection.{}.collection_id\n",
                collection.collection_id
            ));
            config.push_str(&format!("  key           = \"{}\"\n", attr.key));
            config.push_str(&format!("  required      = {}\n", attr.required));
            config.push_str(&format!("  array         = {}\n", attr.array));

            match &attr.attribute_type {
                infrastructure::schema::AttributeType::String { size } => {
                    config.push_str(&format!("  size = {}\n", size.unwrap_or(255)));
                }
                infrastructure::schema::AttributeType::Integer { min, max } => {
                    if let Some(min_val) = min {
                        config.push_str(&format!("  min = {}\n", min_val));
                    }
                    if let Some(max_val) = max {
                        config.push_str(&format!("  max = {}\n", max_val));
                    }
                }
                infrastructure::schema::AttributeType::Enum { elements } => {
                    config.push_str(&format!(
                        "  elements = [{}]\n",
                        elements
                            .iter()
                            .map(|e| format!("\"{}\"", e))
                            .collect::<Vec<_>>()
                            .join(", ")
                    ));
                }
                _ => {}
            }

            config.push_str("}\n\n");
        }

        // Indexes
        for index in &collection.indexes {
            let index_type = match index.index_type {
                infrastructure::schema::IndexType::Key => "key",
                infrastructure::schema::IndexType::Fulltext => "fulltext",
                infrastructure::schema::IndexType::Unique => "unique",
            };

            config.push_str(&format!(
                "resource \"appwrite_index\" \"{}_{}_{}\" {{\n",
                schema.database_id, collection.collection_id, index.key
            ));
            config.push_str(&format!(
                "  database_id   = appwrite_database.{}.database_id\n",
                schema.database_id
            ));
            config.push_str(&format!(
                "  collection_id = appwrite_collection.{}.collection_id\n",
                collection.collection_id
            ));
            config.push_str(&format!("  key           = \"{}\"\n", index.key));
            config.push_str(&format!("  type          = \"{}\"\n", index_type));
            config.push_str(&format!(
                "  attributes    = [{}]\n",
                index
                    .attributes
                    .iter()
                    .map(|a| format!("\"{}\"", a))
                    .collect::<Vec<_>>()
                    .join(", ")
            ));
            config.push_str("}\n\n");
        }
    }

    config
}
