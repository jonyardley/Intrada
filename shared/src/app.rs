use crux_core::{
    macros::effect,
    render::{render, RenderOperation},
    App, Command, capability::Operation,
};
use serde::{Deserialize, Serialize};
use crux_http::{protocol::HttpRequest};

pub mod goal;
pub use goal::*;

pub mod exercise;
pub use exercise::*;

pub mod exercise_record;
pub use exercise_record::*;

pub mod session;
pub use session::{PracticeSession, PracticeSessionView, ActiveSession, SessionState, add_session, edit_session, edit_session_fields, set_active_session, start_session, end_session, remove_active_session, edit_session_notes};

pub mod model;
pub use model::*;

pub mod dev;
pub use dev::*;

// *************
// EVENTS
// *************
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    AddExercise(Exercise),
    EditExercise(Exercise),
    AddExerciseToGoal {
        goal_id: String,
        exercise_id: String,
    },

    AddSession(PracticeSession),
    EditSession(PracticeSession),
    EditSessionFields {
        session_id: String,
        goal_ids: Vec<String>,
        intention: String,
        notes: Option<String>,
    },
    SetActiveSession(String),
    StartSession(String, String),
    UnsetActiveSession(),
    EndSession(String, String),
    EditSessionNotes(String, String),

    AddExerciseRecord(ExerciseRecord),
    UpdateExerciseRecord(ExerciseRecord),

    SetDevData(),
    Nothing,

    // Simple Appwrite Events - just for loading goals
    LoadGoals,
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    DeleteGoal(String),
    #[serde(skip)]
    GoalsLoaded(AppwriteResult),
}

// Simple Appwrite Operation - just for getting goals
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteOperation {
    GetGoals,
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    DeleteGoal(String),
}

impl Operation for AppwriteOperation {
    type Output = AppwriteResult;
}

// Appwrite Result - wrapper for different response types
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteResult {
    Goals(Vec<PracticeGoal>),
    Goal(PracticeGoal), // For create/update operations
    Success, // For delete operations
    Error(String), // For error handling
}

#[effect]
pub enum Effect {
    Render(RenderOperation),
    Http(HttpRequest),
    Appwrite(AppwriteOperation),
}

// *************
// APP
// *************
#[derive(Default)]
pub struct Chopin;

impl App for Chopin {
    type Event = Event;
    type Model = Model;
    type ViewModel = ViewModel;
    type Capabilities = ();
    type Effect = Effect;

    fn update(
        &self,
        event: Self::Event,
        model: &mut Self::Model,
        _caps: &Self::Capabilities,
    ) -> Command<Effect, Event> {
        match event {

            Event::AddExercise(exercise) => add_exercise(exercise, model),
            Event::EditExercise(exercise) => edit_exercise(exercise, model),
            Event::AddExerciseToGoal {
                goal_id,
                exercise_id,
            } => add_exercise_to_goal(goal_id, exercise_id, model),

            Event::AddSession(session) => add_session(session, model),
            Event::EditSession(session) => edit_session(session, model),
            Event::EditSessionFields {
                session_id,
                goal_ids,
                intention,
                notes,
            } => edit_session_fields(session_id, goal_ids, intention, notes, model),
            Event::SetActiveSession(session_id) => set_active_session(session_id, model),
            Event::StartSession(session_id, timestamp) => {
                if let Err(e) = start_session(session_id, timestamp, model) {
                    // You might want to handle this error in your UI
                    println!("Failed to start session: {}", e);
                }
            }

            Event::EndSession(session_id, timestamp) => {
                if let Err(e) = end_session(session_id, timestamp, model) {
                    // You might want to handle this error in your UI
                    println!("Failed to end session: {}", e);
                }
            }
            Event::UnsetActiveSession() => remove_active_session(model),
            Event::EditSessionNotes(session_id, notes) => {
                edit_session_notes(session_id, notes, model)
            }

            Event::AddExerciseRecord(record) => add_exercise_record(record, model),
            Event::UpdateExerciseRecord(record) => update_exercise_record(record, model),

            Event::SetDevData() => dev::set_dev_data(model),

            //Do Nothing
            Event::Nothing => (),

            // Simple Appwrite Events - just for loading goals
            Event::LoadGoals => {
                // Request goals from the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::GetGoals)
                    .then_send(Event::GoalsLoaded);
            }
            Event::CreateGoal(goal) => {
                // Request to create a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::CreateGoal(goal))
                    .then_send(Event::GoalsLoaded);
            }
            Event::UpdateGoal(goal) => {
                // Request to update a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::UpdateGoal(goal))
                    .then_send(Event::GoalsLoaded);
            }
            Event::DeleteGoal(goal_id) => {
                // Request to delete a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::DeleteGoal(goal_id))
                    .then_send(Event::GoalsLoaded);
            }
            Event::GoalsLoaded(result) => {
                // Update the model with the loaded goals
                match result {
                    AppwriteResult::Goals(goals) => {
                        model.goals = goals;
                    }
                    AppwriteResult::Goal(goal) => {
                        // Handle single goal result (for create/update)
                        // You might want to update the existing goal or add it to the list
                        if let Some(existing_index) = model.goals.iter().position(|g| g.id == goal.id) {
                            model.goals[existing_index] = goal;
                        } else {
                            model.goals.push(goal);
                        }
                    }
                    AppwriteResult::Success => {
                        // Handle success case (for delete operations)
                        // No action needed for now
                    }
                    AppwriteResult::Error(error_message) => {
                        // Handle error case
                        println!("Appwrite error: {}", error_message);
                        // You might want to set an error state in the model
                    }
                }
            }
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        let session_views: Vec<PracticeSessionView> = model.sessions.iter().map(|s| {
            PracticeSessionView {
                id: s.id().to_string(),
                goal_ids: s.goal_ids().clone(),
                intention: s.intention().clone(),
                state: s.state(),
                notes: s.notes().clone(),
                exercise_records: s.exercise_records().clone(),
                duration: s.duration(),
                start_time: s.start_time().map(|t| t.to_string()),
                end_time: s.end_time().map(|t| t.to_string()),
                is_ended: s.is_ended(),
            }
        }).collect();

        ViewModel::new(
            model.goals.clone(),
            model.exercises.clone(),
            session_views,
            model.app_state.clone(),
        )
    }
}