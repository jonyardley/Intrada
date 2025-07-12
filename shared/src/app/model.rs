use crate::app::{
    ActiveSession, PracticeGoal, PracticeSession, PracticeSessionView, SessionState, Study,
};
use chrono::{DateTime, Utc};
use facet::Facet;
use serde::{Deserialize, Serialize};

#[derive(Default)]
pub struct Model {
    pub goals: Vec<PracticeGoal>,
    pub studies: Vec<Study>,
    pub sessions: Vec<PracticeSession>,
    pub active_session: Option<ActiveSession>,
}

impl Model {}

#[derive(Facet, Serialize, Deserialize, Clone, Default)]
#[allow(clippy::struct_excessive_bools)]
pub struct ViewModel {
    pub goals: Vec<PracticeGoal>,
    pub studies: Vec<Study>,
    pub sessions: Vec<PracticeSessionView>,
    pub active_session: Option<ActiveSession>,
    // Session state computed properties (replaces SessionManager)
    pub current_session: Option<PracticeSessionView>,
    pub has_active_session: bool,
    pub can_start_session: bool,
    pub can_end_session: bool,
    pub is_session_running: bool,
    pub is_session_ended: bool,
    pub current_session_elapsed_time: Option<String>, // e.g. "01:23:45"
}

impl ViewModel {
    pub fn new(
        goals: Vec<PracticeGoal>,
        studies: Vec<Study>,
        sessions: Vec<PracticeSessionView>,
        active_session: Option<ActiveSession>,
    ) -> Self {
        // Find current session
        let current_session = if let Some(active_session) = &active_session {
            sessions.iter().find(|s| s.id == active_session.id).cloned()
        } else {
            None
        };

        let has_active_session = current_session.is_some();

        // Compute session state flags
        let (can_start_session, can_end_session, is_session_running, is_session_ended) =
            if let Some(ref session) = current_session {
                let can_start = matches!(session.state, SessionState::NotStarted);
                let can_end = matches!(session.state, SessionState::Started { .. });
                let is_running = matches!(session.state, SessionState::Started { .. });
                let is_ended = matches!(session.state, SessionState::Ended { .. });

                (can_start, can_end, is_running, is_ended)
            } else {
                (false, false, false, false)
            };

        // Calculate elapsed time for running sessions
        let current_session_elapsed_time = if let Some(ref session) = current_session {
            match &session.state {
                SessionState::Started { start_time } => {
                    Some(calculate_elapsed_time_from_start(start_time))
                }
                SessionState::Ended {
                    start_time,
                    end_time,
                } => Some(calculate_elapsed_time_between(start_time, end_time)),
                SessionState::NotStarted => None,
            }
        } else {
            None
        };

        Self {
            goals,
            studies,
            sessions,
            active_session,
            current_session,
            has_active_session,
            can_start_session,
            can_end_session,
            is_session_running,
            is_session_ended,
            current_session_elapsed_time,
        }
    }
}

// Helper functions for time calculations
fn calculate_elapsed_time_from_start(start_time: &str) -> String {
    let start = DateTime::parse_from_rfc3339(start_time).unwrap_or_default();
    let now = Utc::now();
    let duration = now.signed_duration_since(start);
    format_duration_hms(duration.num_seconds())
}

fn calculate_elapsed_time_between(start_time: &str, end_time: &str) -> String {
    let start = DateTime::parse_from_rfc3339(start_time).unwrap_or_default();
    let end = DateTime::parse_from_rfc3339(end_time).unwrap_or_default();
    let duration = end.signed_duration_since(start);
    format_duration_hms(duration.num_seconds())
}

fn format_duration_hms(total_seconds: i64) -> String {
    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;
    format!("{hours:02}:{minutes:02}:{seconds:02}")
}
