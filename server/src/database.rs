use anyhow::Result;
use sea_orm::{Database, DatabaseConnection, DbErr};
use sea_orm_migration::MigratorTrait;

pub mod entities;
pub mod migration;

pub async fn create_connection(database_url: &str) -> Result<DatabaseConnection, DbErr> {
    let db = Database::connect(database_url).await?;

    println!("Database connection successful");
    Ok(db)
}

pub async fn run_migrations(db: &DatabaseConnection) -> Result<(), DbErr> {
    migration::Migrator::up(db, None).await?;
    println!("Database migrations completed successfully");
    Ok(())
}
