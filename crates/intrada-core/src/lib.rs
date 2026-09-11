pub mod analytics;
pub mod app;
pub mod domain;
pub mod error;
pub mod http;
pub mod model;
pub mod persistence;
pub(crate) mod priorities;
pub mod recognition;
pub(crate) mod staleness;
pub mod suggestion;
pub mod validation;

pub use app::{AppEffect, Effect, Event, Intrada};
pub use domain::account::{AccountEvent, AccountPreferences};
pub use domain::item::{Item, ItemEvent, ItemKind, Modality};
pub use domain::mcp_audit::{McpAuditEntry, McpAuditEvent};
pub use domain::mcp_tokens::{CreatedMcpToken, McpToken, McpTokenEvent};
pub use domain::oauth::{OAuthEvent, OAuthFinalizeParams};
pub use domain::session::{
    ActiveSession, CompletionStatus, EntryStatus, PracticeSession, SessionEvent, SessionStatus,
    SetlistEntry,
};
pub use domain::set::{Set, SetEntry, SetEvent};
pub use domain::types::{
    CreateItem, LibraryData, LibrarySort, ListQuery, SessionsData, SortDirection, SortField, Tempo,
    UpdateItem,
};
pub use error::LibraryError;
pub use persistence::{PersistenceOperation, PersistenceOutput};
pub use recognition::{
    read_fields, DraftSource, PageReading, PhotoDraft, RecognisedLine, RecognitionOperation,
    RecognitionOutput, SuggestedFields, TempoDraftField, TextDraftField, LOW_CONFIDENCE,
};

// Re-export crux_http protocol types so shells can handle HTTP effects
// without a direct crux_http dependency.
pub use crux_http::protocol::{HttpHeader, HttpResponse, HttpResult};
pub use crux_http::{HttpError, HttpRequest};
pub use model::{
    ActiveSessionView, BuildingSetlistView, ItemPracticeSummary, LibraryItemView, Model,
    PhotoRecognition, PhotoRecognitionStatus, PhotoRecognitionView, PracticeSessionView,
    ScoreHistoryEntry, SessionStatusView, SetEntryView, SetSourceStatus, SetView, SetlistEntryView,
    SummaryView, TempoTrendPoint, TempoTrendView, ViewModel,
};
pub use validation::{
    MAX_ACHIEVED_TEMPO, MAX_BPM, MAX_COMPOSER, MAX_NOTES, MAX_SET_NAME, MAX_TAG, MAX_TEMPO_MARKING,
    MAX_TITLE, MIN_ACHIEVED_TEMPO, MIN_BPM,
};
