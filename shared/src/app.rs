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
pub use goal::{add_goal, add_study_to_goal, edit_goal, GoalEvent, GoalStatus, PracticeGoal};

pub mod study;
pub use study::{add_study, edit_study, Study, StudyEvent};

pub mod study_session;
pub use study_session::{add_study_session, update_study_session, StudySession, StudySessionEvent};

pub mod session;
pub use session::{
    add_session, edit_session_fields, edit_session_notes, end_session, remove_active_session,
    set_active_session, start_session, ActiveSession, PracticeSession, PracticeSessionView,
    SessionEvent, SessionState,
};

pub mod model;
pub use model::*;

pub mod dev;
pub use dev::{set_dev_data, DevEvent};

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
    Dev(DevEvent),
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
            Event::Dev(dev_event) => dev::handle_event(dev_event, model),
        }
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        let session_views: Vec<PracticeSessionView> = model
            .sessions
            .iter()
            .map(Self::session_view_model)
            .collect();

        ViewModel::new(
            model.goals.clone(),
            model.studies.clone(),
            session_views,
            model.active_session.clone(),
        )
    }
}

impl Chopin {
    /// Helper function to convert PracticeSession to PracticeSessionView
    fn session_view_model(session: &PracticeSession) -> PracticeSessionView {
        session::session_view_model(session)
    }
}
