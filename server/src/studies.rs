use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, Pool, Postgres};

use crate::ApiError;

type DbPool = Pool<Postgres>;

// Database row struct
#[derive(FromRow)]
struct StudyRow {
    id: String,
    name: String,
    description: Option<String>,
}

// Request/Response types
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateStudyRequest {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Study {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}


// Routes
pub fn routes() -> Router<DbPool> {
    Router::new()
        .route("/studies", get(get_studies).post(create_study))
}

// Create a new study
async fn create_study(
    State(pool): State<DbPool>,
    Json(req): Json<CreateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    let study_id = uuid::Uuid::new_v4().to_string();

    sqlx::query!(
        "INSERT INTO studies (id, name, description) VALUES ($1, $2, $3)",
        study_id,
        req.name,
        req.description
    )
    .execute(&pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Database error: {e}"),
            }),
        )
    })?;

    let study = Study {
        id: study_id,
        name: req.name,
        description: req.description,
    };

    Ok(Json(study))
}

// Get all studies
async fn get_studies(
    State(pool): State<DbPool>,
) -> Result<Json<Vec<Study>>, (StatusCode, Json<ApiError>)> {
    let rows = sqlx::query_as!(
        StudyRow,
        "SELECT id, name, description FROM studies ORDER BY created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Database error: {e}"),
            }),
        )
    })?;

    let studies = rows
        .into_iter()
        .map(|row| Study {
            id: row.id,
            name: row.name,
            description: row.description,
        })
        .collect();

    Ok(Json(studies))
}
