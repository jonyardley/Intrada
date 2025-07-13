use anyhow::Result;
use axum::{
    Router,
    extract::{Path, State},
    http::StatusCode,
    response::{Html, Json, IntoResponse, Response},
    routing::get,
};
use sea_orm::{ConnectionTrait, DatabaseBackend, DatabaseConnection, Statement, DbErr};
use shared::PracticeGoal;
use std::net::SocketAddr;

mod database;
mod services;

use services::goals::GoalsService;

#[derive(Clone)]
struct AppState {
    db: DatabaseConnection,
}

// Unified error handling
#[derive(Debug)]
enum ApiError {
    NotFound,
    Database(DbErr),
    InvalidInput(String),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = match self {
            ApiError::NotFound => StatusCode::NOT_FOUND,
            ApiError::Database(_) => StatusCode::INTERNAL_SERVER_ERROR,
            ApiError::InvalidInput(_) => StatusCode::BAD_REQUEST,
        };
        status.into_response()
    }
}

impl From<DbErr> for ApiError {
    fn from(err: DbErr) -> Self {
        ApiError::Database(err)
    }
}

type ApiResult<T> = Result<Json<T>, ApiError>;

async fn hello_world() -> Html<&'static str> {
    Html("<h1>Hello, World!</h1>")
}

async fn hello_json() -> &'static str {
    "Hello, World!"
}

async fn health_check(State(state): State<AppState>) -> Result<String, String> {
    let statement = Statement::from_string(DatabaseBackend::Postgres, "SELECT 1");
    match state.db.execute(statement).await {
        Ok(_) => Ok("Database connection healthy".to_string()),
        Err(e) => Err(format!("Database connection failed: {}", e)),
    }
}

// Goals API endpoints
async fn get_goals(State(state): State<AppState>) -> ApiResult<Vec<PracticeGoal>> {
    let goals = GoalsService::get_all_goals(&state.db).await?;
    Ok(Json(goals))
}

async fn get_goal(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> ApiResult<PracticeGoal> {
    let goal = GoalsService::get_goal_by_id(&state.db, &id).await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(goal))
}

async fn create_goal(
    State(state): State<AppState>,
    Json(goal): Json<PracticeGoal>,
) -> ApiResult<PracticeGoal> {
    let created_goal = GoalsService::create_goal(&state.db, goal).await?;
    Ok(Json(created_goal))
}

async fn update_goal(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(mut goal): Json<PracticeGoal>,
) -> ApiResult<PracticeGoal> {
    // Ensure the ID in the path matches the ID in the body
    goal.id = id;
    let updated_goal = GoalsService::update_goal(&state.db, goal).await?;
    Ok(Json(updated_goal))
}

async fn delete_goal(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    GoalsService::delete_goal(&state.db, &id).await?;
    Ok(StatusCode::NO_CONTENT)
}

#[tokio::main]
async fn main() -> Result<()> {
    // Load environment variables from .env file if it exists
    dotenv::dotenv().ok();

    // Get database URL from environment
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    // Create database connection
    let db = database::create_connection(&database_url)
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to database: {}", e))?;

    // Run migrations
    database::run_migrations(&db)
        .await
        .map_err(|e| anyhow::anyhow!("Failed to run migrations: {}", e))?;

    // Create app state
    let app_state = AppState { db };

    // Build our application with routes
    let app = Router::new()
        .route("/", get(hello_world))
        .route("/hello", get(hello_json))
        .route("/health", get(health_check))
        // Goals API routes
        .route("/api/goals", get(get_goals).post(create_goal))
        .route(
            "/api/goals/{id}",
            get(get_goal).put(update_goal).delete(delete_goal),
        )
        .with_state(app_state);

    // Use PORT environment variable or default to 3000 for local development
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a valid number");

    // Run our app with hyper, listening globally on the configured port
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running on http://0.0.0.0:{port}");
    println!("Goals API available at:");
    println!("  GET    /api/goals       - Get all goals");
    println!("  POST   /api/goals       - Create a new goal");
    println!("  GET    /api/goals/{{id}}   - Get a specific goal");
    println!("  PUT    /api/goals/{{id}}   - Update a specific goal");
    println!("  DELETE /api/goals/{{id}}   - Delete a specific goal");

    axum::serve(listener, app).await.unwrap();

    Ok(())
}
