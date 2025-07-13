use crate::database::entities::goal;
use sea_orm::*;
use shared::{GoalStatus, PracticeGoal};
use uuid::Uuid;

pub struct GoalsService;

impl GoalsService {
    /// Convert a shared PracticeGoal to a database Goal model
    fn to_database_model(goal: &PracticeGoal) -> goal::ActiveModel {
        goal::ActiveModel {
            id: Set(Uuid::parse_str(&goal.id).unwrap_or_else(|_| Uuid::new_v4())),
            name: Set(goal.name.clone()),
            description: Set(goal.description.clone()),
            status: Set(serde_json::to_string(&goal.status).unwrap()),
            start_date: Set(goal.start_date.clone()),
            target_date: Set(goal.target_date.clone()),
            study_ids: Set(goal.study_ids.clone()),
            tempo_target: Set(goal.tempo_target),
            created_at: NotSet,
            updated_at: NotSet,
        }
    }

    /// Convert a database Goal model to a shared PracticeGoal
    fn from_database_model(model: goal::Model) -> PracticeGoal {
        PracticeGoal {
            id: model.id.to_string(),
            name: model.name,
            description: model.description,
            status: serde_json::from_str(&model.status).unwrap_or(GoalStatus::NotStarted),
            start_date: model.start_date,
            target_date: model.target_date,
            study_ids: model.study_ids,
            tempo_target: model.tempo_target,
        }
    }

    /// Create a new goal
    pub async fn create_goal(
        db: &DatabaseConnection,
        goal: PracticeGoal,
    ) -> Result<PracticeGoal, DbErr> {
        let active_model = Self::to_database_model(&goal);
        let result = goal::Entity::insert(active_model).exec(db).await?;

        // Fetch the inserted goal to get the database-generated timestamps
        let inserted_goal = goal::Entity::find_by_id(result.last_insert_id)
            .one(db)
            .await?;

        Ok(Self::from_database_model(inserted_goal.unwrap()))
    }

    /// Get all goals
    pub async fn get_all_goals(db: &DatabaseConnection) -> Result<Vec<PracticeGoal>, DbErr> {
        let goals = goal::Entity::find().all(db).await?;
        Ok(goals.into_iter().map(Self::from_database_model).collect())
    }

    /// Get a goal by ID
    pub async fn get_goal_by_id(
        db: &DatabaseConnection,
        id: &str,
    ) -> Result<Option<PracticeGoal>, DbErr> {
        let uuid =
            Uuid::parse_str(id).map_err(|_| DbErr::Custom("Invalid UUID format".to_string()))?;
        let goal = goal::Entity::find_by_id(uuid).one(db).await?;
        Ok(goal.map(Self::from_database_model))
    }

    /// Update a goal
    pub async fn update_goal(
        db: &DatabaseConnection,
        goal: PracticeGoal,
    ) -> Result<PracticeGoal, DbErr> {
        let uuid = Uuid::parse_str(&goal.id)
            .map_err(|_| DbErr::Custom("Invalid UUID format".to_string()))?;

        let mut active_model: goal::ActiveModel = goal::Entity::find_by_id(uuid)
            .one(db)
            .await?
            .ok_or_else(|| DbErr::Custom("Goal not found".to_string()))?
            .into();

        // Update the fields
        active_model.name = Set(goal.name.clone());
        active_model.description = Set(goal.description.clone());
        active_model.status = Set(serde_json::to_string(&goal.status).unwrap());
        active_model.start_date = Set(goal.start_date.clone());
        active_model.target_date = Set(goal.target_date.clone());
        active_model.study_ids = Set(goal.study_ids.clone());
        active_model.tempo_target = Set(goal.tempo_target);

        let updated_goal = active_model.update(db).await?;
        Ok(Self::from_database_model(updated_goal))
    }

    /// Delete a goal
    pub async fn delete_goal(db: &DatabaseConnection, id: &str) -> Result<(), DbErr> {
        let uuid =
            Uuid::parse_str(id).map_err(|_| DbErr::Custom("Invalid UUID format".to_string()))?;
        goal::Entity::delete_by_id(uuid).exec(db).await?;
        Ok(())
    }
}
