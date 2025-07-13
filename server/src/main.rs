use axum::Router;
use serde::Serialize;
use sqlx::PgPool;
use std::net::SocketAddr;

mod goals;

#[derive(Debug, Serialize)]
pub struct ApiError {
    message: String,
}

impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        ApiError {
            message: err.to_string(),
        }
    }
}

async fn setup_database() -> Result<PgPool, sqlx::Error> {
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPool::connect(&database_url).await?;

    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;

    Ok(pool)
}

#[tokio::main]
async fn main() {
    // Load .env file for local development (will be ignored in production)
    dotenvy::dotenv().ok();

    let pool = setup_database().await.expect("Failed to setup database");

    let app = Router::new().merge(goals::routes()).with_state(pool);

    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a valid number");

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running on http://0.0.0.0:{port}");
    axum::serve(listener, app).await.unwrap();
}
