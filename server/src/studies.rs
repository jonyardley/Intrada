use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::{delete, get, post, put},
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

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateStudyRequest {
    pub name: Option<String>,
    pub description: Option<String>,
}

// Routes
pub fn routes() -> Router<DbPool> {
    Router::new()
        .route("/studies", get(get_studies).post(create_study))
        .route(
            "/studies/:id",
            get(get_study).put(update_study).delete(delete_study),
        )
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

// Get a specific study by ID
async fn get_study(
    State(pool): State<DbPool>,
    Path(study_id): Path<String>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    let row = sqlx::query_as!(
        StudyRow,
        "SELECT id, name, description FROM studies WHERE id = $1",
        study_id
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Database error: {e}"),
            }),
        )
    })?;

    match row {
        Some(row) => Ok(Json(Study {
            id: row.id,
            name: row.name,
            description: row.description,
        })),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        )),
    }
}

// Update a study
async fn update_study(
    State(pool): State<DbPool>,
    Path(study_id): Path<String>,
    Json(req): Json<UpdateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    // First, get the existing study
    let existing_study = sqlx::query_as!(
        StudyRow,
        "SELECT id, name, description FROM studies WHERE id = $1",
        study_id
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Database error: {e}"),
            }),
        )
    })?;

    let existing_study = existing_study.ok_or_else(|| {
        (
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        )
    })?;

    // Prepare the updated study
    let updated_study = Study {
        id: study_id.clone(),
        name: req.name.unwrap_or(existing_study.name),
        description: req.description.or(existing_study.description),
    };

    // Update the database
    sqlx::query!(
        "UPDATE studies 
         SET name = $1, description = $2, updated_at = CURRENT_TIMESTAMP 
         WHERE id = $3",
        updated_study.name,
        updated_study.description,
        study_id
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

    Ok(Json(updated_study))
}

// Delete a study
async fn delete_study(
    State(pool): State<DbPool>,
    Path(study_id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let result = sqlx::query!("DELETE FROM studies WHERE id = $1", study_id)
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

    if result.rows_affected() == 0 {
        return Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        ));
    }

    Ok(StatusCode::NO_CONTENT)
}