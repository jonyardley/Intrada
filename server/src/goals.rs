use axum::{
    Router,
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
};
use serde::Deserialize;
use shared::{GoalStatus, PracticeGoal};
use sqlx::{FromRow, Pool, Postgres};

use crate::ApiError;

type DbPool = Pool<Postgres>;

// Database row struct - much clearer than tuples
#[derive(FromRow)]
struct GoalRow {
    id: String,
    name: String,
    description: Option<String>,
    status: String,
    start_date: Option<String>,
    target_date: Option<String>,
    study_ids: String, // JSON string
    tempo_target: Option<i32>,
}

impl GoalRow {
    fn into_goal(self) -> Result<PracticeGoal, (StatusCode, Json<ApiError>)> {
        // Parse study IDs from JSON
        let study_ids: Vec<String> = serde_json::from_str(&self.study_ids).map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiError {
                    message: format!("Failed to parse study IDs: {e}"),
                }),
            )
        })?;

        // Parse status
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

    // Convert study IDs to JSON string
    let study_ids_json = serde_json::to_string(&req.study_ids).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Failed to serialize study IDs: {e}"),
            }),
        )
    })?;

    // Insert into database
    sqlx::query(
        "INSERT INTO goals (id, name, description, status, start_date, target_date, study_ids, tempo_target) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
    )
    .bind(&goal.id)
    .bind(&goal.name)
    .bind(&goal.description)
    .bind("NotStarted")
    .bind(&goal.start_date)
    .bind(&goal.target_date)
    .bind(&study_ids_json)
    .bind(goal.tempo_target.map(|t| t as i32))
    .execute(&pool)
    .await
    .map_err(|e| (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(ApiError { message: format!("Database error: {e}") })
    ))?;

    Ok(Json(goal))
}

async fn get_goals(
    State(pool): State<DbPool>,
) -> Result<Json<Vec<PracticeGoal>>, (StatusCode, Json<ApiError>)> {
    // Fetch all goals from database
    let rows = sqlx::query_as::<_, GoalRow>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
         FROM goals ORDER BY created_at DESC",
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

    // Convert database rows to goals
    let mut goals = Vec::new();
    for row in rows {
        goals.push(row.into_goal()?);
    }

    Ok(Json(goals))
}

async fn get_goal(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<Json<PracticeGoal>, (StatusCode, Json<ApiError>)> {
    // Fetch goal from database
    let row = sqlx::query_as::<_, GoalRow>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
         FROM goals WHERE id = $1",
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

    // Check if goal exists
    match row {
        Some(row) => Ok(Json(row.into_goal()?)),
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
    let existing_row = sqlx::query_as::<_, GoalRow>(
        "SELECT id, name, description, status, start_date, target_date, study_ids, tempo_target 
         FROM goals WHERE id = $1",
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

    let existing_goal = match existing_row {
        Some(row) => row.into_goal()?,
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

    // Convert study IDs to JSON string
    let study_ids_json = serde_json::to_string(&updated_goal.study_ids).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                message: format!("Failed to serialize study IDs: {e}"),
            }),
        )
    })?;

    // Convert status to string
    let status_str = match updated_goal.status {
        GoalStatus::NotStarted => "NotStarted",
        GoalStatus::InProgress => "InProgress",
        GoalStatus::Completed => "Completed",
    };

    // Update in database
    sqlx::query(
        "UPDATE goals SET name = $2, description = $3, status = $4, start_date = $5, target_date = $6, 
         study_ids = $7, tempo_target = $8, updated_at = CURRENT_TIMESTAMP 
         WHERE id = $1"
    )
    .bind(&id)
    .bind(&updated_goal.name)
    .bind(&updated_goal.description)
    .bind(status_str)
    .bind(&updated_goal.start_date)
    .bind(&updated_goal.target_date)
    .bind(&study_ids_json)
    .bind(updated_goal.tempo_target.map(|t| t as i32))
    .execute(&pool)
    .await
    .map_err(|e| (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(ApiError { message: format!("Database error: {e}") })
    ))?;

    Ok(Json(updated_goal))
}

async fn delete_goal(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let result = sqlx::query("DELETE FROM goals WHERE id = $1")
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
                message: "Goal not found".to_string(),
            }),
        ));
    }

    Ok(StatusCode::NO_CONTENT)
}

pub fn routes() -> Router<DbPool> {
    Router::new()
        .route("/goals", get(get_goals).post(create_goal))
        .route(
            "/goals/{id}",
            get(get_goal).put(update_goal).delete(delete_goal),
        )
}
