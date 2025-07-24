use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde::Deserialize;
use shared::Study;
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

impl StudyRow {
    fn into_study(self) -> Study {
        Study {
            id: self.id,
            name: self.name,
            description: self.description,
        }
    }
}

// Request types
#[derive(Debug, Deserialize)]
pub struct CreateStudyRequest {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStudyRequest {
    pub name: Option<String>,
    pub description: Option<String>,
}

async fn create_study(
    State(pool): State<DbPool>,
    Json(req): Json<CreateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    let study = Study::new(req.name, req.description);

    // Insert into database
    sqlx::query(
        "INSERT INTO studies (id, name, description) 
         VALUES ($1, $2, $3)",
    )
    .bind(&study.id)
    .bind(&study.name)
    .bind(&study.description)
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

    Ok(Json(study))
}

async fn get_studies(
    State(pool): State<DbPool>,
) -> Result<Json<Vec<Study>>, (StatusCode, Json<ApiError>)> {
    // Fetch all studies from database
    let rows = sqlx::query_as::<_, StudyRow>(
        "SELECT id, name, description 
         FROM studies ORDER BY created_at DESC",
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

    // Convert database rows to studies
    let studies: Vec<Study> = rows.into_iter().map(|row| row.into_study()).collect();

    Ok(Json(studies))
}

async fn get_study(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    // Fetch study from database
    let row = sqlx::query_as::<_, StudyRow>(
        "SELECT id, name, description 
         FROM studies WHERE id = $1",
    )
    .bind(&id)
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

    // Check if study exists
    match row {
        Some(row) => Ok(Json(row.into_study())),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        )),
    }
}

async fn update_study(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
    Json(req): Json<UpdateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    // First, get the existing study
    let existing_row = sqlx::query_as::<_, StudyRow>(
        "SELECT id, name, description 
         FROM studies WHERE id = $1",
    )
    .bind(&id)
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

    let existing_study = match existing_row {
        Some(row) => row.into_study(),
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Study not found".to_string(),
                }),
            ));
        }
    };

    // Create updated study with new values or existing ones
    let updated_study = Study {
        id: existing_study.id,
        name: req.name.unwrap_or(existing_study.name),
        description: req.description.or(existing_study.description),
    };

    // Update in database
    sqlx::query(
        "UPDATE studies SET name = $2, description = $3, updated_at = CURRENT_TIMESTAMP 
         WHERE id = $1",
    )
    .bind(&id)
    .bind(&updated_study.name)
    .bind(&updated_study.description)
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

async fn delete_study(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let result = sqlx::query("DELETE FROM studies WHERE id = $1")
        .bind(&id)
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

pub fn routes() -> Router<DbPool> {
    Router::new()
        .route("/studies", get(get_studies).post(create_study))
        .route(
            "/studies/{id}",
            get(get_study).put(update_study).delete(delete_study),
        )
}

// *************
// TESTS
// *************

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_study_row_into_study() {
        let study_row = StudyRow {
            id: "test-id".to_string(),
            name: "Test Study".to_string(),
            description: Some("Test description".to_string()),
        };

        let study = study_row.into_study();
        assert_eq!(study.id, "test-id");
        assert_eq!(study.name, "Test Study");
        assert_eq!(study.description, Some("Test description".to_string()));
    }

    #[test]
    fn test_study_row_into_study_no_description() {
        let study_row = StudyRow {
            id: "test-id".to_string(),
            name: "Test Study".to_string(),
            description: None,
        };

        let study = study_row.into_study();
        assert_eq!(study.id, "test-id");
        assert_eq!(study.name, "Test Study");
        assert_eq!(study.description, None);
    }

    #[test]
    fn test_create_study_request_validation() {
        let request = CreateStudyRequest {
            name: "Test Study".to_string(),
            description: Some("Description".to_string()),
        };

        assert_eq!(request.name, "Test Study");
        assert_eq!(request.description, Some("Description".to_string()));
    }

    #[test]
    fn test_update_study_request_partial_update() {
        let request = UpdateStudyRequest {
            name: Some("Updated Name".to_string()),
            description: None,
        };

        assert_eq!(request.name, Some("Updated Name".to_string()));
        assert_eq!(request.description, None);
    }

    #[test]
    fn test_create_study_request_no_description() {
        let request = CreateStudyRequest {
            name: "Test Study".to_string(),
            description: None,
        };

        assert_eq!(request.name, "Test Study");
        assert_eq!(request.description, None);
    }
}
