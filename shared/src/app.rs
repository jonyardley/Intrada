use crux_core::{
    macros::effect,
    render::{render, RenderOperation},
    App, Command,
};
use crux_http::{command::Http, protocol::HttpRequest};
use facet::Facet;
use serde::{Deserialize, Serialize};

const API_URL: &str = "http://localhost:3000/goals";

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
            Event::Goal(goal_event) => match goal_event {
                GoalEvent::FetchGoals => {
                    return Http::get(API_URL)
                        .expect_json()
                        .build()
                        .map(Into::into)
                        .then_send(|response| Event::Goal(GoalEvent::SetGoals(response)));
                }
                GoalEvent::SetGoals(HttpResult::Ok(mut response)) => {
                    let goals = response.take_body().unwrap();
                    return Command::event(Event::Goal(GoalEvent::UpdateGoals(goals)));
                }
                GoalEvent::SetGoals(HttpResult::Err(e)) => {
                    eprintln!("Failed to fetch goals: {e:?}");
                    // TODO: Add proper error handling - show error to user
                }
                GoalEvent::UpdateGoals(goals) => model.goals = goals,
                GoalEvent::AddGoal(goal) => {
                    // Transform PracticeGoal to the format the server expects
                    let create_request = serde_json::json!({
                        "name": goal.name,
                        "description": goal.description,
                        "target_date": goal.target_date,
                        "study_ids": goal.study_ids,
                        "tempo_target": goal.tempo_target
                    });

                    let json_string =
                        serde_json::to_string(&create_request).expect("Failed to serialize JSON");
                    eprintln!("Creating goal with JSON: {json_string}");

                    return Http::post(API_URL)
                        .header("Content-Type", "application/json")
                        .body(json_string)
                        .expect_json::<goal::PracticeGoal>()
                        .build()
                        .map(Into::into)
                        .then_send(|response| Event::Goal(GoalEvent::GoalCreated(response)));
                }
                GoalEvent::GoalCreated(HttpResult::Ok(mut response)) => {
                    let created_goal = response.take_body().unwrap();
                    goal::add_goal(created_goal, model);
                }
                GoalEvent::GoalCreated(HttpResult::Err(e)) => {
                    eprintln!("Failed to create goal: {e:?}");
                    // TODO: Add proper error handling - show error to user
                }
                GoalEvent::EditGoal(goal) => goal::edit_goal(goal, model),
            },

            Event::Study(study_event) => match study_event {
                StudyEvent::AddStudy(study) => add_study(study, model),
                StudyEvent::EditStudy(study) => edit_study(study, model),
                StudyEvent::AddStudyToGoal { goal_id, study_id } => {
                    add_study_to_goal(&goal_id, &study_id, model);
                }
            },

            Event::Session(session_event) => match session_event {
                SessionEvent::AddSession(session) => add_session(session, model),
                SessionEvent::EditSessionFields {
                    session_id,
                    goal_ids,
                    intention,
                    notes,
                } => edit_session_fields(&session_id, goal_ids, intention, notes, model),
                SessionEvent::SetActiveSession(session_id) => set_active_session(session_id, model),
                SessionEvent::StartSession(session_id, timestamp) => {
                    Self::handle_session_result(
                        start_session(&session_id, timestamp, model),
                        "start",
                    );
                }
                SessionEvent::EndSession(session_id, timestamp) => {
                    Self::handle_session_result(end_session(&session_id, timestamp, model), "end");
                }
                SessionEvent::UnsetActiveSession => remove_active_session(model),
                SessionEvent::EditSessionNotes(session_id, notes) => {
                    edit_session_notes(&session_id, notes, model);
                }
            },

            Event::StudySession(study_session_event) => match study_session_event {
                StudySessionEvent::AddStudySession(session) => add_study_session(session, model),
                StudySessionEvent::UpdateStudySession(session) => {
                    update_study_session(session, model)
                }
            },

            Event::Dev(dev_event) => match dev_event {
                DevEvent::SetDevData => dev::set_dev_data(model),
                DevEvent::Nothing => (),
            },
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
    fn handle_session_result(result: Result<(), SessionError>, operation: &str) {
        if let Err(e) = result {
            log::error!("Failed to {operation} session: {e}");
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
