use facet::Facet;
use serde::{Deserialize, Serialize};

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum SessionError {
    AlreadyStarted,
    AlreadyEnded,
    NotStarted,
    NotActive,
    NotFound,
    InvalidTransition { from: String, to: String },
}

impl std::fmt::Display for SessionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SessionError::AlreadyStarted => write!(f, "Session is already started"),
            SessionError::AlreadyEnded => write!(f, "Session is already ended"),
            SessionError::NotStarted => write!(f, "Session has not been started"),
            SessionError::NotActive => write!(f, "Session is not active"),
            SessionError::NotFound => write!(f, "Session not found"),
            SessionError::InvalidTransition { from, to } => {
                write!(f, "Invalid transition from '{from}' to '{to}'")
            }
        }
    }
}

impl std::error::Error for SessionError {}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum GoalError {
    AlreadyCompleted,
    NotStarted,
    NotFound,
    InvalidTransition { from: String, to: String },
}

impl std::fmt::Display for GoalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            GoalError::AlreadyCompleted => write!(f, "Goal is already completed"),
            GoalError::NotStarted => write!(f, "Goal has not been started"),
            GoalError::NotFound => write!(f, "Goal not found"),
            GoalError::InvalidTransition { from, to } => {
                write!(f, "Invalid transition from '{from}' to '{to}'")
            }
        }
    }
}

impl std::error::Error for GoalError {}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum AppError {
    Session(SessionError),
    Goal(GoalError),
    Http(String),
    Serialization(String),
    Unknown(String),
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AppError::Session(e) => write!(f, "Session error: {e}"),
            AppError::Goal(e) => write!(f, "Goal error: {e}"),
            AppError::Http(msg) => write!(f, "HTTP error: {msg}"),
            AppError::Serialization(msg) => write!(f, "Serialization error: {msg}"),
            AppError::Unknown(msg) => write!(f, "Unknown error: {msg}"),
        }
    }
}

impl std::error::Error for AppError {}

impl From<SessionError> for AppError {
    fn from(error: SessionError) -> Self {
        AppError::Session(error)
    }
}

impl From<GoalError> for AppError {
    fn from(error: GoalError) -> Self {
        AppError::Goal(error)
    }
}

impl From<serde_json::Error> for AppError {
    fn from(error: serde_json::Error) -> Self {
        AppError::Serialization(error.to_string())
    }
}
