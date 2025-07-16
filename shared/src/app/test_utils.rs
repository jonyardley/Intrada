use crate::app::{
    goal::PracticeGoal, model::Model, session::PracticeSession, study::Study,
    study_session::StudySession, GoalStatus,
};

/// Test utilities for creating common test objects and scenarios
/// Creates a default test model
pub fn create_test_model() -> Model {
    Model::default()
}

/// Creates a test model with pre-populated data
pub fn create_populated_test_model() -> Model {
    let mut model = Model::default();

    // Add test goals
    model
        .goals
        .push(create_test_goal("Test Goal 1", Some("Description 1")));
    model.goals.push(create_test_goal("Test Goal 2", None));

    // Add test studies
    model
        .studies
        .push(create_test_study("Test Study 1", Some("Study description")));
    model.studies.push(create_test_study("Test Study 2", None));

    // Add test sessions
    model
        .sessions
        .push(create_test_session(&["goal1"], "Test session 1"));
    model
        .sessions
        .push(create_test_session(&["goal2"], "Test session 2"));

    model
}

/// Creates a test goal with default values
pub fn create_test_goal(name: &str, description: Option<&str>) -> PracticeGoal {
    PracticeGoal::new(
        name.to_string(),
        description.map(|d| d.to_string()),
        None,   // target_date
        vec![], // study_ids
        None,   // tempo_target
    )
}

/// Creates a test goal with custom fields
pub fn create_custom_test_goal(
    name: &str,
    description: Option<&str>,
    status: GoalStatus,
    study_ids: Vec<String>,
    tempo_target: Option<u32>,
) -> PracticeGoal {
    let mut goal = create_test_goal(name, description);
    goal.status = status;
    goal.study_ids = study_ids;
    goal.tempo_target = tempo_target;
    goal
}

/// Creates a test study with default values
pub fn create_test_study(name: &str, description: Option<&str>) -> Study {
    Study::new(name.to_string(), description.map(|d| d.to_string()))
}

/// Creates a test session with default values
pub fn create_test_session(goal_ids: &[&str], intention: &str) -> PracticeSession {
    PracticeSession::new(
        goal_ids.iter().map(|id| id.to_string()).collect(),
        intention.to_string(),
    )
}

/// Creates a test session with specified ID for testing
/// Note: This is a placeholder - custom ID setting would need to be implemented
pub fn create_test_session_with_id(
    goal_ids: &[&str],
    intention: &str,
    _custom_id: &str,
) -> PracticeSession {
    create_test_session(goal_ids, intention)
}

/// Creates a test study session
pub fn create_test_study_session(study_id: &str, session_id: &str) -> StudySession {
    StudySession::new(study_id.to_string(), session_id.to_string())
}

/// Creates a started test session for testing timing scenarios
pub fn create_started_test_session(goal_ids: &[&str], intention: &str) -> PracticeSession {
    let mut session = create_test_session(goal_ids, intention);
    session.start("2025-01-01T12:00:00Z".to_string()).unwrap();
    session
}

/// Creates an ended test session for testing completed scenarios
pub fn create_ended_test_session(goal_ids: &[&str], intention: &str) -> PracticeSession {
    let mut session = create_started_test_session(goal_ids, intention);
    session.end("2025-01-01T12:30:00Z".to_string()).unwrap();
    session
}

/// Helper to add a session to a model and return the session ID
pub fn add_session_to_model(model: &mut Model, session: PracticeSession) -> String {
    let session_id = session.id().to_string();
    model.sessions.push(session);
    session_id
}

/// Helper to add a goal to a model and return the goal ID
pub fn add_goal_to_model(model: &mut Model, goal: PracticeGoal) -> String {
    let goal_id = goal.id.clone();
    model.goals.push(goal);
    goal_id
}

/// Helper to add a study to a model and return the study ID
pub fn add_study_to_model(model: &mut Model, study: Study) -> String {
    let study_id = study.id.clone();
    model.studies.push(study);
    study_id
}

/// Creates a model with a complete practice scenario
pub fn create_practice_scenario() -> (Model, String, String, String) {
    let mut model = create_test_model();

    let goal = create_test_goal(
        "Learn Bach Invention #1",
        Some("Focus on fingering and tempo"),
    );
    let goal_id = add_goal_to_model(&mut model, goal);

    let study = create_test_study("Bach Inventions", Some("Two-part inventions"));
    let study_id = add_study_to_model(&mut model, study);

    let session = create_test_session(&[&goal_id], "Practice slow with metronome");
    let session_id = add_session_to_model(&mut model, session);

    (model, goal_id, study_id, session_id)
}

/// Test assertion helpers
pub fn assert_model_has_sessions(model: &Model, expected_count: usize) {
    assert_eq!(
        model.sessions.len(),
        expected_count,
        "Model should have {expected_count} sessions"
    );
}

pub fn assert_model_has_goals(model: &Model, expected_count: usize) {
    assert_eq!(
        model.goals.len(),
        expected_count,
        "Model should have {expected_count} goals"
    );
}

pub fn assert_model_has_studies(model: &Model, expected_count: usize) {
    assert_eq!(
        model.studies.len(),
        expected_count,
        "Model should have {expected_count} studies"
    );
}

pub fn assert_session_is_started(session: &PracticeSession) {
    assert!(session.is_active(), "Session should be started");
    assert!(
        session.start_time().is_some(),
        "Session should have start time"
    );
}

pub fn assert_session_is_ended(session: &PracticeSession) {
    assert!(session.is_ended(), "Session should be ended");
    assert!(
        session.start_time().is_some(),
        "Session should have start time"
    );
    assert!(session.end_time().is_some(), "Session should have end time");
    assert!(session.duration().is_some(), "Session should have duration");
}
