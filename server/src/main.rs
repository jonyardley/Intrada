use axum::{response::Json, routing::get, Router};
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use std::net::SocketAddr;

mod goals;
mod studies;

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

    let health = || async { Json(json!({ "status": "ok" })) };

    let app = Router::new()
        .route(
            "/",
            get(|| async {
                Json(json!({ "message": "Hello, world! This is the Intrada Server..." }))
            }),
        )
        .route("/health", get(health))
        .merge(goals::routes())
        .merge(studies::routes())
        .with_state(pool);

    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a valid number");

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running on http://0.0.0.0:{port}");
    axum::serve(listener, app).await.unwrap();
}

// *************
// TESTS
// *************

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_api_error_from_string() {
        let error_msg = "Test error message";
        let api_error = ApiError {
            message: error_msg.to_string(),
        };

        assert_eq!(api_error.message, error_msg);
    }

    #[test]
    fn test_api_error_debug() {
        let api_error = ApiError {
            message: "Debug test".to_string(),
        };

        let debug_str = format!("{api_error:?}");
        assert!(debug_str.contains("Debug test"));
    }

    #[test]
    fn test_api_error_serialization() {
        let api_error = ApiError {
            message: "Serialization test".to_string(),
        };

        let serialized = serde_json::to_string(&api_error).unwrap();
        assert!(serialized.contains("Serialization test"));
        assert!(serialized.contains("message"));
    }

    #[test]
    fn test_port_parsing() {
        // Test valid port
        let port_str = "8080";
        let port: u16 = port_str.parse().unwrap();
        assert_eq!(port, 8080);

        // Test default port value
        let default_port = "3000";
        let port: u16 = default_port.parse().unwrap();
        assert_eq!(port, 3000);
    }

    #[test]
    fn test_socket_addr_creation() {
        let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
        assert_eq!(addr.port(), 3000);
        assert_eq!(addr.ip().to_string(), "0.0.0.0");
    }

    #[test]
    fn test_router_creation() {
        // Test that we can create a router without panicking
        let router = Router::new()
            .merge(goals::routes())
            .merge(studies::routes());

        // This is a basic smoke test - the router should be created successfully
        // In a real integration test, we'd test the actual routes
        assert!(format!("{router:?}").contains("Router"));
    }
}