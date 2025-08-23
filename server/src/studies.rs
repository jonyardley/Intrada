use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde::Deserialize;
use shared::Study;
use sqlx::FromRow;
use std::sync::Arc;

use crate::{
    repository::{Database, RepositoryError, RepositoryResult},
    ApiError,
};

// Database row struct
#[derive(FromRow)]
pub struct StudyRow {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}

impl StudyRow {
    pub fn into_study(self) -> Study {
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

// Simple Study repository - no traits, just methods
pub struct StudyRepository {
    db: Database,
}

impl StudyRepository {
    pub fn new(pool: crate::repository::DbPool) -> Self {
        Self {
            db: Database::new(pool),
        }
    }

    pub async fn create(&self, study: &Study) -> RepositoryResult<()> {
        sqlx::query("INSERT INTO studies (id, name, description) VALUES ($1, $2, $3)")
            .bind(&study.id)
            .bind(&study.name)
            .bind(&study.description)
            .execute(&self.db.pool)
            .await?;

        Ok(())
    }

    pub async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<Study>> {
        let row = sqlx::query_as!(
            StudyRow,
            "SELECT id, name, description FROM studies WHERE id = $1",
            id
        )
        .fetch_optional(&self.db.pool)
        .await?;

        Ok(row.map(|r| r.into_study()))
    }

    pub async fn find_all(&self) -> RepositoryResult<Vec<Study>> {
        let rows = sqlx::query_as!(
            StudyRow,
            "SELECT id, name, description FROM studies ORDER BY created_at DESC"
        )
        .fetch_all(&self.db.pool)
        .await?;

        Ok(rows.into_iter().map(|row| row.into_study()).collect())
    }

    pub async fn update(&self, study: &Study) -> RepositoryResult<()> {
        let result = sqlx::query(
            "UPDATE studies SET name = $2, description = $3, updated_at = CURRENT_TIMESTAMP 
             WHERE id = $1",
        )
        .bind(&study.id)
        .bind(&study.name)
        .bind(&study.description)
        .execute(&self.db.pool)
        .await?;

        if result.rows_affected() == 0 {
            return Err(RepositoryError::NotFound(format!(
                "Study with id {}",
                study.id
            )));
        }

        Ok(())
    }

    pub async fn delete(&self, id: &str) -> RepositoryResult<bool> {
        let result = sqlx::query("DELETE FROM studies WHERE id = $1")
            .bind(id)
            .execute(&self.db.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    // Domain-specific methods - no trait constraints
    pub async fn _find_by_name_pattern(&self, pattern: &str) -> RepositoryResult<Vec<Study>> {
        let search_pattern = format!("%{pattern}%");
        let rows = sqlx::query_as!(
            StudyRow,
            "SELECT id, name, description FROM studies 
             WHERE LOWER(name) LIKE LOWER($1) ORDER BY created_at DESC",
            search_pattern
        )
        .fetch_all(&self.db.pool)
        .await?;

        Ok(rows.into_iter().map(|row| row.into_study()).collect())
    }
}

// HTTP Handlers
async fn create_study(
    State(study_repo): State<Arc<StudyRepository>>,
    Json(req): Json<CreateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    let study = Study::new(req.name, req.description);

    study_repo
        .create(&study)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(study))
}

async fn get_studies(
    State(study_repo): State<Arc<StudyRepository>>,
) -> Result<Json<Vec<Study>>, (StatusCode, Json<ApiError>)> {
    let studies = study_repo
        .find_all()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(studies))
}

async fn get_study(
    State(study_repo): State<Arc<StudyRepository>>,
    Path(id): Path<String>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    let study = study_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    match study {
        Some(study) => Ok(Json(study)),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        )),
    }
}

async fn update_study(
    State(study_repo): State<Arc<StudyRepository>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateStudyRequest>,
) -> Result<Json<Study>, (StatusCode, Json<ApiError>)> {
    // Get existing study
    let existing_study = study_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let existing_study = match existing_study {
        Some(study) => study,
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

    study_repo
        .update(&updated_study)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(updated_study))
}

async fn delete_study(
    State(study_repo): State<Arc<StudyRepository>>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let deleted = study_repo
        .delete(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Study not found".to_string(),
            }),
        ))
    }
}

pub fn routes() -> Router<Arc<StudyRepository>> {
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
    use std::sync::Mutex;

    // Simple mock repository for testing
    struct MockStudyRepository {
        studies: Mutex<Vec<Study>>,
    }

    impl MockStudyRepository {
        fn new() -> Self {
            Self {
                studies: Mutex::new(Vec::new()),
            }
        }

        async fn create(&self, study: &Study) -> RepositoryResult<()> {
            let mut studies = self.studies.lock().unwrap();
            studies.push(study.clone());
            Ok(())
        }

        async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<Study>> {
            let studies = self.studies.lock().unwrap();
            Ok(studies.iter().find(|s| s.id == id).cloned())
        }

        async fn find_all(&self) -> RepositoryResult<Vec<Study>> {
            let studies = self.studies.lock().unwrap();
            Ok(studies.clone())
        }

        async fn update(&self, study: &Study) -> RepositoryResult<()> {
            let mut studies = self.studies.lock().unwrap();
            if let Some(existing) = studies.iter_mut().find(|s| s.id == study.id) {
                *existing = study.clone();
                Ok(())
            } else {
                Err(RepositoryError::NotFound(study.id.clone()))
            }
        }

        async fn delete(&self, id: &str) -> RepositoryResult<bool> {
            let mut studies = self.studies.lock().unwrap();
            if let Some(pos) = studies.iter().position(|s| s.id == id) {
                studies.remove(pos);
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    #[test]
    fn test_study_row_conversion() {
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

    #[tokio::test]
    async fn test_mock_repository_operations() {
        let mock_repo = MockStudyRepository::new();

        let study = Study::new("Test Study".to_string(), Some("Description".to_string()));
        let study_id = study.id.clone();

        // Test create
        mock_repo.create(&study).await.unwrap();

        // Test find_by_id
        let found = mock_repo.find_by_id(&study_id).await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "Test Study");

        // Test find_all
        let all_studies = mock_repo.find_all().await.unwrap();
        assert_eq!(all_studies.len(), 1);

        // Test update
        let mut updated_study = study.clone();
        updated_study.name = "Updated Study".to_string();
        mock_repo.update(&updated_study).await.unwrap();

        let found = mock_repo.find_by_id(&study_id).await.unwrap().unwrap();
        assert_eq!(found.name, "Updated Study");

        // Test delete
        let deleted = mock_repo.delete(&study_id).await.unwrap();
        assert!(deleted);

        let found = mock_repo.find_by_id(&study_id).await.unwrap();
        assert!(found.is_none());
    }
}
