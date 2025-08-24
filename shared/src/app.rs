use crux_core::{macros::effect, render::RenderOperation, App, Command};
use crux_http::protocol::HttpRequest;
use facet::Facet;
use serde::{Deserialize, Serialize};

// Simple wrapper for HTTP results that can work with Facet
#[derive(Facet, Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[repr(C)]
pub enum HttpResult<T, E> {
    Ok(T),
    Err(E),
}

impl<T> From<crux_http::Result<crux_http::Response<T>>>
    for HttpResult<crux_http::Response<T>, crux_http::HttpError>
{
    fn from(value: crux_http::Result<crux_http::Response<T>>) -> Self {
        match value {
            Ok(response) => HttpResult::Ok(response),
            Err(error) => HttpResult::Err(error),
        }
    }
}

pub mod error;
pub use error::*;

pub mod goal;
pub use goal::{add_study_to_goal, GoalEvent, GoalStatus, PracticeGoal};

pub mod study;
pub use study::{Study, StudyEvent};

pub mod study_session;
pub use study_session::{StudySession, StudySessionEvent};

pub mod session;
pub use session::{
    complete_reflection, edit_session_fields, edit_session_notes, end_session, start_session,
    PracticeSession, SessionEvent, SessionState,
};

pub mod model;
pub use model::*;

pub mod utils;
pub use utils::{
    generate_id, handle_http_error, handle_operation_result, is_valid_id, short_id,
    validate_and_log,
};

pub mod http_utils;
pub use http_utils::{
    api_delete, api_get, api_post, api_put, delete_request, get_request, post_json_request,
    put_json_request,
};

pub mod repository;
pub use repository::{GoalRepository, Repository, SessionRepository, StudyRepository};

#[cfg(test)]
pub mod test_utils;
#[cfg(test)]
pub use test_utils::*;

// *************
// EVENTS
// *************

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum Event {
    Goal(GoalEvent),
    Study(StudyEvent),
    Session(SessionEvent),
    StudySession(StudySessionEvent),
    FetchAll,
    Error(String),
    ClearError,
    // Local store reconciliation events
    ReconcileFromLocal {
        goals: Vec<PracticeGoal>,
        studies: Vec<Study>,
        sessions: Vec<PracticeSession>,
    },
    SyncPendingChanges,
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
            Event::Goal(goal_event) => goal::handle_event(goal_event, model),
            Event::Study(study_event) => study::handle_event(study_event, model),
            Event::Session(session_event) => session::handle_event(session_event, model),
            Event::StudySession(study_session_event) => {
                study_session::handle_event(study_session_event, model)
            }
            Event::FetchAll => {
                // Orchestrate all sync operations by dispatching individual sync events
                Command::all(vec![
                    Command::event(Event::Goal(GoalEvent::SyncGoals)),
                    Command::event(Event::Study(StudyEvent::SyncStudies)),
                    Command::event(Event::Session(SessionEvent::SyncSessions)),
                ])
            }
            Event::Error(error_message) => {
                model.last_error = Some(error_message);
                Command::done()
            }
            Event::ClearError => {
                model.last_error = None;
                Command::done()
            }
            Event::ReconcileFromLocal {
                goals,
                studies,
                sessions,
            } => {
                // Update model with local data - used on app start and after local changes
                model.goals = goals;
                model.studies = studies;
                model.sessions = sessions;
                crux_core::render::render()
            }
            Event::SyncPendingChanges => {
                // Trigger sync of all pending changes to server
                // This will be handled by the iOS layer - just acknowledge here
                crux_core::render::render()
            }
        }
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        ViewModel::new(
            model.goals.clone(),
            model.studies.clone(),
            model.sessions.clone(),
            model.last_error.clone(),
        )
    }
}

impl Chopin {}
