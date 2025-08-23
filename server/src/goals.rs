use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde::Deserialize;
use shared::{GoalStatus, PracticeGoal};
use sqlx::FromRow;
use std::sync::Arc;

use crate::{
    repository::{Database, RepositoryError, RepositoryResult},
    ApiError,
};

// Database row struct
#[derive(FromRow)]
pub struct GoalRow {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub status: String,
    pub start_date: Option<String>,
    pub target_date: Option<String>,
    pub study_ids: String, // JSON string
    pub tempo_target: Option<i32>,
}

impl GoalRow {
    pub fn into_goal(self) -> RepositoryResult<PracticeGoal> {
        let study_ids: Vec<String> = serde_json::from_str(&self.study_ids)?;
        let status = match self.status.as_str() {
            "NotStarted" => GoalStatus::NotStarted,
            "InProgress" => GoalStatus::InProgress,
            "Completed" => GoalStatus::Completed,
            _ => GoalStatus::NotStarted,
        };

        Ok(PracticeGoal {
            id: self.id,
            name: self.name,
            description: self.description,
            status,
            start_date: self.start_date,
            target_date: self.target_date,
            study_ids,
            tempo_target: self.tempo_target.map(|t| t as u32),
        })
    }
}

// Request types
#[derive(Debug, Deserialize)]
pub struct CreateGoalRequest {
    pub name: String,
    pub description: Option<String>,
    pub target_date: Option<String>,
    pub study_ids: Vec<String>,
    pub tempo_target: Option<u32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGoalRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub status: Option<GoalStatus>,
    pub start_date: Option<String>,
    pub target_date: Option<String>,
    pub study_ids: Option<Vec<String>>,
    pub tempo_target: Option<u32>,
}

// Simple Goal repository - no traits, just methods
pub struct GoalRepository {
    db: Database,
}

impl GoalRepository {
    pub fn new(pool: crate::repository::DbPool) -> Self {
        Self {
            db: Database::new(pool),
        }
    }

    fn status_to_string(status: &GoalStatus) -> &'static str {
        match status {
            GoalStatus::NotStarted => "NotStarted",
            GoalStatus::InProgress => "InProgress",
            GoalStatus::Completed => "Completed",
        }
    }

    pub async fn create(&self, goal: &PracticeGoal) -> RepositoryResult<()> {
        let study_ids_json = serde_json::to_string(&goal.study_ids)?;

        sqlx::query(
            "INSERT INTO goals (id, name, description, status, start_date, target_date, study_ids, tempo_target) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
        )
        .bind(&goal.id)
        .bind(&goal.name)
        .bind(&goal.description)
        .bind(Self::status_to_string(&goal.status))
        .bind(&goal.start_date)
        .bind(&goal.target_date)
        .bind(&study_ids_json)
        .bind(goal.tempo_target.map(|t| t as i32))
        .execute(&self.db.pool)
        .await?;

        Ok(())
    }

    pub async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<PracticeGoal>> {
        let row = sqlx::query_as!(
            GoalRow,
            "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
             FROM goals WHERE id = $1",
            id
        )
        .fetch_optional(&self.db.pool)
        .await?;

        match row {
            Some(row) => Ok(Some(row.into_goal()?)),
            None => Ok(None),
        }
    }

    pub async fn find_all(&self) -> RepositoryResult<Vec<PracticeGoal>> {
        let rows = sqlx::query_as!(
            GoalRow,
            "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
             FROM goals ORDER BY created_at DESC"
        )
        .fetch_all(&self.db.pool)
        .await?;

        let mut goals = Vec::new();
        for row in rows {
            goals.push(row.into_goal()?);
        }
        Ok(goals)
    }

    pub async fn update(&self, goal: &PracticeGoal) -> RepositoryResult<()> {
        let study_ids_json = serde_json::to_string(&goal.study_ids)?;

        let result = sqlx::query(
            "UPDATE goals SET name = $2, description = $3, status = $4, start_date = $5, 
             target_date = $6, study_ids = $7, tempo_target = $8, updated_at = CURRENT_TIMESTAMP 
             WHERE id = $1",
        )
        .bind(&goal.id)
        .bind(&goal.name)
        .bind(&goal.description)
        .bind(Self::status_to_string(&goal.status))
        .bind(&goal.start_date)
        .bind(&goal.target_date)
        .bind(&study_ids_json)
        .bind(goal.tempo_target.map(|t| t as i32))
        .execute(&self.db.pool)
        .await?;

        if result.rows_affected() == 0 {
            return Err(RepositoryError::NotFound(format!(
                "Goal with id {}",
                goal.id
            )));
        }

        Ok(())
    }

    pub async fn delete(&self, id: &str) -> RepositoryResult<bool> {
        let result = sqlx::query("DELETE FROM goals WHERE id = $1")
            .bind(id)
            .execute(&self.db.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    // Domain-specific methods - no trait constraints
    pub async fn _find_by_status(&self, status: GoalStatus) -> RepositoryResult<Vec<PracticeGoal>> {
        let status_str = Self::status_to_string(&status);
        let rows = sqlx::query_as!(
            GoalRow,
            "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
             FROM goals WHERE status = $1 ORDER BY created_at DESC",
            status_str
        )
        .fetch_all(&self.db.pool)
        .await?;

        let mut goals = Vec::new();
        for row in rows {
            goals.push(row.into_goal()?);
        }
        Ok(goals)
    }

    pub async fn _find_by_study_id(&self, study_id: &str) -> RepositoryResult<Vec<PracticeGoal>> {
        let study_pattern = format!("%\"{study_id}\"%");
        let rows = sqlx::query_as!(
            GoalRow,
            "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
             FROM goals WHERE study_ids LIKE $1 ORDER BY created_at DESC",
            study_pattern
        )
        .fetch_all(&self.db.pool)
        .await?;

        let mut goals = Vec::new();
        for row in rows {
            let goal = row.into_goal()?;
            // Double-check the study_id is actually in the list (not just substring match)
            if goal.study_ids.contains(&study_id.to_string()) {
                goals.push(goal);
            }
        }
        Ok(goals)
    }
}

// HTTP Handlers
async fn create_goal(
    State(goal_repo): State<Arc<GoalRepository>>,
    Json(req): Json<CreateGoalRequest>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    let goal = PracticeGoal::new(
        req.name,
        req.description,
        req.target_date,
        req.study_ids,
        req.tempo_target,
    );

    goal_repo
        .create(&goal)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(goal))
}

async fn get_goals(
    State(goal_repo): State<Arc<GoalRepository>>,
) -> Result<Json<Vec<PracticeGoal>>, (StatusCode, Json<ApiError>)> {
    let goals = goal_repo
        .find_all()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(goals))
}

async fn get_goal(
    State(goal_repo): State<Arc<GoalRepository>>,
    Path(id): Path<String>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    let goal = goal_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    match goal {
        Some(goal) => Ok(Json(goal)),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Goal not found".to_string(),
            }),
        )),
    }
}

async fn update_goal(
    State(goal_repo): State<Arc<GoalRepository>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateGoalRequest>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    // Get existing goal
    let existing_goal = goal_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let existing_goal = match existing_goal {
        Some(goal) => goal,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Goal not found".to_string(),
                }),
            ));
        }
    };

    // Create updated goal with new values or existing ones
    let updated_goal = PracticeGoal {
        id: existing_goal.id,
        name: req.name.unwrap_or(existing_goal.name),
        description: req.description.or(existing_goal.description),
        status: req.status.unwrap_or(existing_goal.status),
        start_date: req.start_date.or(existing_goal.start_date),
        target_date: req.target_date.or(existing_goal.target_date),
        study_ids: req.study_ids.unwrap_or(existing_goal.study_ids),
        tempo_target: req.tempo_target.or(existing_goal.tempo_target),
    };

    goal_repo
        .update(&updated_goal)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(updated_goal))
}

async fn delete_goal(
    State(goal_repo): State<Arc<GoalRepository>>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let deleted = goal_repo
        .delete(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Goal not found".to_string(),
            }),
        ))
    }
}

pub fn routes() -> Router<Arc<GoalRepository>> {
    Router::new()
        .route("/goals", get(get_goals).post(create_goal))
        .route(
            "/goals/{id}",
            get(get_goal).put(update_goal).delete(delete_goal),
        )
}

// *************
// TESTS
// *************

#[cfg(test)]
mod tests {
    use super::*;
    use shared::GoalStatus;
    use std::sync::Mutex;

    // Simple mock repository for testing
    struct MockGoalRepository {
        goals: Mutex<Vec<PracticeGoal>>,
    }

    impl MockGoalRepository {
        fn new() -> Self {
            Self {
                goals: Mutex::new(Vec::new()),
            }
        }

        async fn create(&self, goal: &PracticeGoal) -> RepositoryResult<()> {
            let mut goals = self.goals.lock().unwrap();
            goals.push(goal.clone());
            Ok(())
        }

        async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<PracticeGoal>> {
            let goals = self.goals.lock().unwrap();
            Ok(goals.iter().find(|g| g.id == id).cloned())
        }

        async fn find_all(&self) -> RepositoryResult<Vec<PracticeGoal>> {
            let goals = self.goals.lock().unwrap();
            Ok(goals.clone())
        }

        async fn update(&self, goal: &PracticeGoal) -> RepositoryResult<()> {
            let mut goals = self.goals.lock().unwrap();
            if let Some(existing) = goals.iter_mut().find(|g| g.id == goal.id) {
                *existing = goal.clone();
                Ok(())
            } else {
                Err(RepositoryError::NotFound(goal.id.clone()))
            }
        }

        async fn delete(&self, id: &str) -> RepositoryResult<bool> {
            let mut goals = self.goals.lock().unwrap();
            if let Some(pos) = goals.iter().position(|g| g.id == id) {
                goals.remove(pos);
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    #[test]
    fn test_goal_row_conversion() {
        let goal_row = GoalRow {
            id: "test-id".to_string(),
            name: "Test Goal".to_string(),
            description: Some("Test description".to_string()),
            status: "InProgress".to_string(),
            start_date: Some("2024-01-01".to_string()),
            target_date: Some("2024-12-31".to_string()),
            study_ids: r#"["study1", "study2"]"#.to_string(),
            tempo_target: Some(120),
        };

        let goal = goal_row.into_goal().unwrap();
        assert_eq!(goal.id, "test-id");
        assert_eq!(goal.name, "Test Goal");
        assert_eq!(goal.status, GoalStatus::InProgress);
        assert_eq!(goal.study_ids, vec!["study1", "study2"]);
        assert_eq!(goal.tempo_target, Some(120));
    }

    #[test]
    fn test_create_goal_request_validation() {
        let request = CreateGoalRequest {
            name: "Test Goal".to_string(),
            description: Some("Description".to_string()),
            target_date: Some("2024-12-31".to_string()),
            study_ids: vec!["study1".to_string(), "study2".to_string()],
            tempo_target: Some(120),
        };

        assert_eq!(request.name, "Test Goal");
        assert_eq!(request.description, Some("Description".to_string()));
        assert_eq!(request.target_date, Some("2024-12-31".to_string()));
        assert_eq!(request.study_ids, vec!["study1", "study2"]);
        assert_eq!(request.tempo_target, Some(120));
    }

    #[test]
    fn test_update_goal_request_partial_update() {
        let request = UpdateGoalRequest {
            name: Some("Updated Name".to_string()),
            description: None,
            status: Some(GoalStatus::Completed),
            start_date: None,
            target_date: None,
            study_ids: None,
            tempo_target: Some(140),
        };

        assert_eq!(request.name, Some("Updated Name".to_string()));
        assert_eq!(request.description, None);
        assert_eq!(request.status, Some(GoalStatus::Completed));
        assert_eq!(request.tempo_target, Some(140));
    }

    #[tokio::test]
    async fn test_mock_repository_operations() {
        let mock_repo = MockGoalRepository::new();

        let goal = PracticeGoal::new(
            "Test Goal".to_string(),
            Some("Description".to_string()),
            None,
            vec![],
            None,
        );
        let goal_id = goal.id.clone();

        // Test create
        mock_repo.create(&goal).await.unwrap();

        // Test find_by_id
        let found = mock_repo.find_by_id(&goal_id).await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "Test Goal");

        // Test find_all
        let all_goals = mock_repo.find_all().await.unwrap();
        assert_eq!(all_goals.len(), 1);

        // Test update
        let mut updated_goal = goal.clone();
        updated_goal.name = "Updated Goal".to_string();
        mock_repo.update(&updated_goal).await.unwrap();

        let found = mock_repo.find_by_id(&goal_id).await.unwrap().unwrap();
        assert_eq!(found.name, "Updated Goal");

        // Test delete
        let deleted = mock_repo.delete(&goal_id).await.unwrap();
        assert!(deleted);

        let found = mock_repo.find_by_id(&goal_id).await.unwrap();
        assert!(found.is_none());
    }

    #[test]
    fn test_status_to_string() {
        assert_eq!(
            GoalRepository::status_to_string(&GoalStatus::NotStarted),
            "NotStarted"
        );
        assert_eq!(
            GoalRepository::status_to_string(&GoalStatus::InProgress),
            "InProgress"
        );
        assert_eq!(
            GoalRepository::status_to_string(&GoalStatus::Completed),
            "Completed"
        );
    }
}
