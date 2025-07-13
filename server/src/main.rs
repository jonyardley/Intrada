use axum::{
    Router,
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
};
use serde::{Deserialize, Serialize};
use shared::{GoalStatus, PracticeGoal};
use sqlx::{Pool, Sqlite, SqlitePool};
use std::net::SocketAddr;

// Database connection type
type DbPool = Pool<Sqlite>;

#[derive(Debug, Serialize)]
struct ApiError {
    message: String,
}

impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        ApiError {
            message: err.to_string(),
        }
    }
}

// Request/Response types
#[derive(Debug, Deserialize)]
struct CreateGoalRequest {
    name: String,
    description: Option<String>,
    target_date: Option<String>,
    study_ids: Vec<String>,
    tempo_target: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct UpdateGoalRequest {
    name: Option<String>,
    description: Option<String>,
    status: Option<GoalStatus>,
    start_date: Option<String>,
    target_date: Option<String>,
    study_ids: Option<Vec<String>>,
    tempo_target: Option<u32>,
}

async fn setup_database() -> Result<DbPool, sqlx::Error> {
    // Use in-memory SQLite for simplicity
    let pool = SqlitePool::connect("sqlite::memory:").await?;

    // Create goals table
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS goals (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            status TEXT NOT NULL DEFAULT 'NotStarted',
            start_date TEXT,
            target_date TEXT,
            study_ids TEXT NOT NULL DEFAULT '[]',
            tempo_target INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        "#,
    )
    .execute(&pool)
    .await?;

    Ok(pool)
}

// CRUD Handlers
async fn create_goal(
    State(pool): State<DbPool>,
    Json(req): Json<CreateGoalRequest>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    let goal = PracticeGoal::new(
        req.name,
        req.description,
        req.target_date,
        req.study_ids.clone(),
        req.tempo_target,
    );

    let study_ids_json = serde_json::to_string(&req.study_ids).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    sqlx::query(
        "INSERT INTO goals (id, name, description, status, start_date, target_date, study_ids, tempo_target) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    )
    .bind(&goal.id)
    .bind(&goal.name)
    .bind(&goal.description)
    .bind("NotStarted")
    .bind(&goal.start_date)
    .bind(&goal.target_date)
    .bind(&study_ids_json)
    .bind(goal.tempo_target)
    .execute(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    Ok(Json(goal))
}

async fn get_goals(
    State(pool): State<DbPool>,
) -> Result<Json<Vec<PracticeGoal>>, (StatusCode, Json<ApiError>)> {
    let rows = sqlx::query_as::<_, (String, String, Option<String>, String, Option<String>, Option<String>, String, Option<u32>)>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target FROM goals ORDER BY created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    let goals: Result<Vec<PracticeGoal>, serde_json::Error> = rows
        .into_iter()
        .map(
            |(
                id,
                name,
                description,
                status,
                start_date,
                target_date,
                study_ids_json,
                tempo_target,
            )| {
                let study_ids: Vec<String> = serde_json::from_str(&study_ids_json)?;
                let goal_status = match status.as_str() {
                    "NotStarted" => GoalStatus::NotStarted,
                    "InProgress" => GoalStatus::InProgress,
                    "Completed" => GoalStatus::Completed,
                    _ => GoalStatus::NotStarted,
                };

                Ok(PracticeGoal {
                    id,
                    name,
                    description,
                    status: goal_status,
                    start_date,
                    target_date,
                    study_ids,
                    tempo_target,
                })
            },
        )
        .collect();

    let goals = goals.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    Ok(Json(goals))
}

async fn get_goal(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    let row = sqlx::query_as::<_, (String, String, Option<String>, String, Option<String>, Option<String>, String, Option<u32>)>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target FROM goals WHERE id = ?"
    )
    .bind(&id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    match row {
        Some((
            id,
            name,
            description,
            status,
            start_date,
            target_date,
            study_ids_json,
            tempo_target,
        )) => {
            let study_ids: Vec<String> = serde_json::from_str(&study_ids_json).map_err(|e| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(ApiError {
                        message: e.to_string(),
                    }),
                )
            })?;

            let goal_status = match status.as_str() {
                "NotStarted" => GoalStatus::NotStarted,
                "InProgress" => GoalStatus::InProgress,
                "Completed" => GoalStatus::Completed,
                _ => GoalStatus::NotStarted,
            };

            let goal = PracticeGoal {
                id,
                name,
                description,
                status: goal_status,
                start_date,
                target_date,
                study_ids,
                tempo_target,
            };

            Ok(Json(goal))
        }
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Goal not found".to_string(),
            }),
        )),
    }
}

async fn update_goal(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
    Json(req): Json<UpdateGoalRequest>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    // First, get the existing goal
    let existing = sqlx::query_as::<_, (String, String, Option<String>, String, Option<String>, Option<String>, String, Option<u32>)>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target FROM goals WHERE id = ?"
    )
    .bind(&id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    let (
        existing_id,
        existing_name,
        existing_description,
        existing_status,
        existing_start_date,
        existing_target_date,
        existing_study_ids_json,
        existing_tempo_target,
    ) = existing.ok_or_else(|| {
        (
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Goal not found".to_string(),
            }),
        )
    })?;

    // Parse existing study_ids
    let existing_study_ids: Vec<String> =
        serde_json::from_str(&existing_study_ids_json).map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiError {
                    message: e.to_string(),
                }),
            )
        })?;

    // Update fields
    let updated_name = req.name.unwrap_or(existing_name);
    let updated_description = req.description.or(existing_description);
    let updated_status = req.status.unwrap_or(match existing_status.as_str() {
        "NotStarted" => GoalStatus::NotStarted,
        "InProgress" => GoalStatus::InProgress,
        "Completed" => GoalStatus::Completed,
        _ => GoalStatus::NotStarted,
    });
    let updated_start_date = req.start_date.or(existing_start_date);
    let updated_target_date = req.target_date.or(existing_target_date);
    let updated_study_ids = req.study_ids.unwrap_or(existing_study_ids);
    let updated_tempo_target = req.tempo_target.or(existing_tempo_target);

    let study_ids_json = serde_json::to_string(&updated_study_ids).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    let status_str = match updated_status {
        GoalStatus::NotStarted => "NotStarted",
        GoalStatus::InProgress => "InProgress",
        GoalStatus::Completed => "Completed",
    };

    sqlx::query(
        "UPDATE goals SET name = ?, description = ?, status = ?, start_date = ?, target_date = ?, study_ids = ?, tempo_target = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
    )
    .bind(&updated_name)
    .bind(&updated_description)
    .bind(status_str)
    .bind(&updated_start_date)
    .bind(&updated_target_date)
    .bind(&study_ids_json)
    .bind(updated_tempo_target)
    .bind(&id)
    .execute(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    let updated_goal = PracticeGoal {
        id: existing_id,
        name: updated_name,
        description: updated_description,
        status: updated_status,
        start_date: updated_start_date,
        target_date: updated_target_date,
        study_ids: updated_study_ids,
        tempo_target: updated_tempo_target,
    };

    Ok(Json(updated_goal))
}

async fn delete_goal(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let result = sqlx::query("DELETE FROM goals WHERE id = ?")
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiError::from(e))))?;

    if result.rows_affected() == 0 {
        return Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Goal not found".to_string(),
            }),
        ));
    }

    Ok(StatusCode::NO_CONTENT)
}

#[tokio::main]
async fn main() {
    // Setup database
    let pool = setup_database().await.expect("Failed to setup database");

    // Build our application with routes
    let app = Router::new()
        .route("/goals", get(get_goals).post(create_goal))
        .route(
            "/goals/{id}",
            get(get_goal).put(update_goal).delete(delete_goal),
        )
        .with_state(pool);

    // Use PORT environment variable or default to 3000 for local development
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a valid number");

    // Run our app with hyper, listening globally on the configured port
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running on http://0.0.0.0:{port}");

    axum::serve(listener, app).await.unwrap();
}
