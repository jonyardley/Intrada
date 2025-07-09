use crux_core::{
    capability::Operation,
    macros::effect,
    render::{render, RenderOperation},
    App, Command,
};
use crux_http::protocol::HttpRequest;
use facet::Facet;
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
#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
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
    UnsetActiveSession,
    EndSession(String, String),
    EditSessionNotes(String, String),

    AddStudySession(StudySession),
    UpdateStudySession(StudySession),

    SetDevData,
    Nothing,

    // Simple Appwrite Events - just for loading goals
    LoadGoals,
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    DeleteGoal(String),
}

#[effect(facet_typegen)]
pub enum Effect {
    Render(RenderOperation),
    Http(HttpRequest),
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
                add_study_to_goal(&goal_id, &study_id, model);
            }

            Event::AddSession(session) => add_session(session, model),
            Event::EditSessionFields {
                session_id,
                goal_ids,
                intention,
                notes,
            } => edit_session_fields(&session_id, goal_ids, intention, notes, model),
            Event::SetActiveSession(session_id) => set_active_session(session_id, model),
            Event::StartSession(session_id, timestamp) => {
                Self::handle_session_result(start_session(&session_id, timestamp, model), "start");
            }

            Event::EndSession(session_id, timestamp) => {
                Self::handle_session_result(end_session(&session_id, timestamp, model), "end");
            }
            Event::UnsetActiveSession => remove_active_session(model),
            Event::EditSessionNotes(session_id, notes) => {
                edit_session_notes(&session_id, notes, model);
            }

            Event::AddStudySession(session) => add_study_session(session, model),
            Event::UpdateStudySession(session) => update_study_session(session, model),

            Event::SetDevData => dev::set_dev_data(model),

            //Do Nothing
            Event::Nothing => (),

            // Simple Appwrite Events - just for loading goals
            Event::LoadGoals => return Command::done(),
            Event::CreateGoal(goal) => return Command::done(),
            Event::UpdateGoal(goal) => return Command::done(),
            Event::DeleteGoal(goal_id) => return Command::done(),
        }

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
    /// Helper function to handle session operation results
    fn handle_session_result(result: Result<(), &'static str>, operation: &str) {
        if let Err(e) = result {
            println!("Failed to {operation} session: {e}");
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
            start_time: session.start_time().map(std::string::ToString::to_string),
            end_time: session.end_time().map(std::string::ToString::to_string),
            is_ended: session.is_ended(),
        }
    }
}
