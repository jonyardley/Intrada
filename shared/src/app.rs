use crux_core::{
    capability::Operation,
    macros::effect,
    render::{render, RenderOperation},
    App, Command,
};
use crux_http::protocol::HttpRequest;
use serde::{Deserialize, Serialize};

pub mod goal;
pub use goal::*;

pub mod study;
pub use study::*;

pub mod study_session;
pub use study_session::*;

pub mod session;
pub use session::{
    add_session, edit_session_fields, edit_session_notes, end_session, remove_active_session,
    set_active_session, start_session, ActiveSession, PracticeSession, PracticeSessionView,
    SessionState,
};

pub mod model;
pub use model::*;

pub mod dev;
pub use dev::*;

// *************
// EVENTS
// *************
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    AddStudy(Study),
    EditStudy(Study),
    AddStudyToGoal {
        goal_id: String,
        study_id: String,
    },

    AddSession(PracticeSession),
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

    AddStudySession(StudySession),
    UpdateStudySession(StudySession),

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
    Success,            // For delete operations
    Error(String),      // For error handling
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
            Event::AddStudy(study) => add_study(study, model),
            Event::EditStudy(study) => edit_study(study, model),
            Event::AddStudyToGoal { goal_id, study_id } => {
                add_study_to_goal(goal_id, study_id, model)
            }

            Event::AddSession(session) => add_session(session, model),
            Event::EditSessionFields {
                session_id,
                goal_ids,
                intention,
                notes,
            } => edit_session_fields(session_id, goal_ids, intention, notes, model),
            Event::SetActiveSession(session_id) => set_active_session(session_id, model),
            Event::StartSession(session_id, timestamp) => {
                Self::handle_session_result(start_session(session_id, timestamp, model), "start")
            }

            Event::EndSession(session_id, timestamp) => {
                Self::handle_session_result(end_session(session_id, timestamp, model), "end")
            }
            Event::UnsetActiveSession() => remove_active_session(model),
            Event::EditSessionNotes(session_id, notes) => {
                edit_session_notes(session_id, notes, model)
            }

            Event::AddStudySession(session) => add_study_session(session, model),
            Event::UpdateStudySession(session) => update_study_session(session, model),

            Event::SetDevData() => dev::set_dev_data(model),

            //Do Nothing
            Event::Nothing => (),

            // Simple Appwrite Events - just for loading goals
            Event::LoadGoals => return Self::appwrite_command(AppwriteOperation::GetGoals),
            Event::CreateGoal(goal) => {
                return Self::appwrite_command(AppwriteOperation::CreateGoal(goal))
            }
            Event::UpdateGoal(goal) => {
                return Self::appwrite_command(AppwriteOperation::UpdateGoal(goal))
            }
            Event::DeleteGoal(goal_id) => {
                return Self::appwrite_command(AppwriteOperation::DeleteGoal(goal_id))
            }
            Event::GoalsLoaded(result) => {
                Self::handle_goals_result(result, model);
            }
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        let session_views: Vec<PracticeSessionView> =
            model.sessions.iter().map(Self::session_to_view).collect();

        ViewModel::new(
            model.goals.clone(),
            model.studies.clone(),
            session_views,
            model.active_session.clone(),
        )
    }
}

impl Chopin {
    /// Helper function to create Appwrite commands
    fn appwrite_command(operation: AppwriteOperation) -> Command<Effect, Event> {
        Command::request_from_shell(operation).then_send(Event::GoalsLoaded)
    }

    /// Helper function to handle session operation results
    fn handle_session_result(result: Result<(), &'static str>, operation: &str) {
        if let Err(e) = result {
            println!("Failed to {operation} session: {e}");
        }
    }

    /// Helper function to handle goals loaded results
    fn handle_goals_result(result: AppwriteResult, model: &mut Model) {
        match result {
            AppwriteResult::Goals(goals) => {
                model.goals = goals;
            }
            AppwriteResult::Goal(goal) => {
                // Handle single goal result (for create/update)
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
                println!("Appwrite error: {error_message}");
                // You might want to set an error state in the model
            }
        }
    }

    /// Helper function to convert PracticeSession to PracticeSessionView
    fn session_to_view(session: &PracticeSession) -> PracticeSessionView {
        PracticeSessionView {
            id: session.id().to_string(),
            goal_ids: session.goal_ids().clone(),
            intention: session.intention().clone(),
            state: session.state(),
            notes: session.notes().clone(),
            study_sessions: session.study_sessions().clone(),
            duration: session.duration(),
            start_time: session.start_time().map(|t| t.to_string()),
            end_time: session.end_time().map(|t| t.to_string()),
            is_ended: session.is_ended(),
        }
    }
}
