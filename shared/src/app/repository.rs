/// Repository pattern for data access operations
use crate::app::model::Model;
use crate::app::{PracticeGoal, PracticeSession, Study};

/// Generic repository trait for common data operations
pub trait Repository<T> {
    /// Find entity by ID
    fn find_by_id(&self, id: &str) -> Option<&T>;

    /// Find mutable entity by ID
    fn find_mut_by_id(&mut self, id: &str) -> Option<&mut T>;

    /// Add entity to repository
    fn add(&mut self, entity: T);

    /// Update entity in repository
    fn update(&mut self, entity: T) -> bool;

    /// Remove entity by ID
    fn remove(&mut self, id: &str) -> Option<T>;

    /// Get all entities
    fn all(&self) -> Vec<&T>;

    /// Count entities
    fn count(&self) -> usize;

    /// Check if entity exists
    fn exists(&self, id: &str) -> bool {
        self.find_by_id(id).is_some()
    }
}

/// Goal repository implementation
pub struct GoalRepository<'a> {
    model: &'a mut Model,
}

impl<'a> GoalRepository<'a> {
    pub fn new(model: &'a mut Model) -> Self {
        Self { model }
    }

    /// Find goals by status
    pub fn find_by_status(&self, status: &crate::app::GoalStatus) -> Vec<&PracticeGoal> {
        self.model
            .goals
            .iter()
            .filter(|goal| &goal.status == status)
            .collect()
    }

    /// Find goals containing a specific study
    pub fn find_by_study_id(&self, study_id: &str) -> Vec<&PracticeGoal> {
        self.model
            .goals
            .iter()
            .filter(|goal| goal.study_ids.contains(&study_id.to_string()))
            .collect()
    }
}

impl<'a> Repository<PracticeGoal> for GoalRepository<'a> {
    fn find_by_id(&self, id: &str) -> Option<&PracticeGoal> {
        self.model.goals.iter().find(|goal| goal.id == id)
    }

    fn find_mut_by_id(&mut self, id: &str) -> Option<&mut PracticeGoal> {
        self.model.goals.iter_mut().find(|goal| goal.id == id)
    }

    fn add(&mut self, entity: PracticeGoal) {
        self.model.goals.push(entity);
    }

    fn update(&mut self, entity: PracticeGoal) -> bool {
        if let Some(goal) = self.find_mut_by_id(&entity.id) {
            *goal = entity;
            true
        } else {
            false
        }
    }

    fn remove(&mut self, id: &str) -> Option<PracticeGoal> {
        if let Some(pos) = self.model.goals.iter().position(|goal| goal.id == id) {
            Some(self.model.goals.remove(pos))
        } else {
            None
        }
    }

    fn all(&self) -> Vec<&PracticeGoal> {
        self.model.goals.iter().collect()
    }

    fn count(&self) -> usize {
        self.model.goals.len()
    }
}

/// Study repository implementation
pub struct StudyRepository<'a> {
    model: &'a mut Model,
}

impl<'a> StudyRepository<'a> {
    pub fn new(model: &'a mut Model) -> Self {
        Self { model }
    }

    /// Find studies by name pattern
    pub fn find_by_name_pattern(&self, pattern: &str) -> Vec<&Study> {
        self.model
            .studies
            .iter()
            .filter(|study| study.name.to_lowercase().contains(&pattern.to_lowercase()))
            .collect()
    }
}

impl<'a> Repository<Study> for StudyRepository<'a> {
    fn find_by_id(&self, id: &str) -> Option<&Study> {
        self.model.studies.iter().find(|study| study.id == id)
    }

    fn find_mut_by_id(&mut self, id: &str) -> Option<&mut Study> {
        self.model.studies.iter_mut().find(|study| study.id == id)
    }

    fn add(&mut self, entity: Study) {
        self.model.studies.push(entity);
    }

    fn update(&mut self, entity: Study) -> bool {
        if let Some(study) = self.find_mut_by_id(&entity.id) {
            *study = entity;
            true
        } else {
            false
        }
    }

    fn remove(&mut self, id: &str) -> Option<Study> {
        if let Some(pos) = self.model.studies.iter().position(|study| study.id == id) {
            Some(self.model.studies.remove(pos))
        } else {
            None
        }
    }

    fn all(&self) -> Vec<&Study> {
        self.model.studies.iter().collect()
    }

    fn count(&self) -> usize {
        self.model.studies.len()
    }
}

/// Session repository implementation
pub struct SessionRepository<'a> {
    model: &'a mut Model,
}

impl<'a> SessionRepository<'a> {
    pub fn new(model: &'a mut Model) -> Self {
        Self { model }
    }

    /// Find active sessions
    pub fn find_active(&self) -> Vec<&PracticeSession> {
        self.model
            .sessions
            .iter()
            .filter(|session| session.is_active())
            .collect()
    }

    /// Find completed sessions
    pub fn find_completed(&self) -> Vec<&PracticeSession> {
        self.model
            .sessions
            .iter()
            .filter(|session| session.is_ended())
            .collect()
    }

    /// Find sessions for a specific goal
    pub fn find_by_goal_id(&self, goal_id: &str) -> Vec<&PracticeSession> {
        self.model
            .sessions
            .iter()
            .filter(|session| session.goal_ids().contains(&goal_id.to_string()))
            .collect()
    }
}

impl<'a> Repository<PracticeSession> for SessionRepository<'a> {
    fn find_by_id(&self, id: &str) -> Option<&PracticeSession> {
        self.model
            .sessions
            .iter()
            .find(|session| session.id() == id)
    }

    fn find_mut_by_id(&mut self, id: &str) -> Option<&mut PracticeSession> {
        self.model
            .sessions
            .iter_mut()
            .find(|session| session.id() == id)
    }

    fn add(&mut self, entity: PracticeSession) {
        self.model.sessions.push(entity);
    }

    fn update(&mut self, entity: PracticeSession) -> bool {
        if let Some(session) = self.find_mut_by_id(entity.id()) {
            *session = entity;
            true
        } else {
            false
        }
    }

    fn remove(&mut self, id: &str) -> Option<PracticeSession> {
        if let Some(pos) = self
            .model
            .sessions
            .iter()
            .position(|session| session.id() == id)
        {
            Some(self.model.sessions.remove(pos))
        } else {
            None
        }
    }

    fn all(&self) -> Vec<&PracticeSession> {
        self.model.sessions.iter().collect()
    }

    fn count(&self) -> usize {
        self.model.sessions.len()
    }
}

/// Convenience functions for creating repositories
impl Model {
    /// Create a goal repository
    pub fn goals(&mut self) -> GoalRepository<'_> {
        GoalRepository::new(self)
    }

    /// Create a study repository
    pub fn studies(&mut self) -> StudyRepository<'_> {
        StudyRepository::new(self)
    }

    /// Create a session repository
    pub fn sessions(&mut self) -> SessionRepository<'_> {
        SessionRepository::new(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::test_utils::*;

    #[test]
    fn test_goal_repository_operations() {
        let mut model = create_test_model();
        let mut repo = model.goals();

        let goal = create_test_goal("Test Goal", Some("Description"));
        let goal_id = goal.id.clone();

        // Test add
        repo.add(goal);
        assert_eq!(repo.count(), 1);

        // Test find_by_id
        assert!(repo.find_by_id(&goal_id).is_some());
        assert!(repo.find_by_id("nonexistent").is_none());

        // Test update
        let mut updated_goal = create_test_goal("Updated Goal", Some("Updated Description"));
        updated_goal.id = goal_id.clone();
        assert!(repo.update(updated_goal));

        let found_goal = repo.find_by_id(&goal_id).unwrap();
        assert_eq!(found_goal.name, "Updated Goal");

        // Test remove
        assert!(repo.remove(&goal_id).is_some());
        assert_eq!(repo.count(), 0);
    }

    #[test]
    fn test_study_repository_operations() {
        let mut model = create_test_model();
        let mut repo = model.studies();

        let study = create_test_study("Test Study", Some("Description"));
        let study_id = study.id.clone();

        // Test add and find
        repo.add(study);
        assert_eq!(repo.count(), 1);
        assert!(repo.find_by_id(&study_id).is_some());

        // Test find_by_name_pattern
        let results = repo.find_by_name_pattern("test");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].name, "Test Study");

        let no_results = repo.find_by_name_pattern("nonexistent");
        assert_eq!(no_results.len(), 0);
    }

    #[test]
    fn test_session_repository_operations() {
        let mut model = create_test_model();
        let mut repo = model.sessions();

        let session = create_test_session(&["goal1"], "Test Session");
        let session_id = session.id().to_string();

        // Test add and find
        repo.add(session);
        assert_eq!(repo.count(), 1);
        assert!(repo.find_by_id(&session_id).is_some());

        // Test find_by_goal_id
        let goal_sessions = repo.find_by_goal_id("goal1");
        assert_eq!(goal_sessions.len(), 1);

        let no_sessions = repo.find_by_goal_id("nonexistent");
        assert_eq!(no_sessions.len(), 0);
    }
}
