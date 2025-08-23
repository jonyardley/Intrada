# StudySession Time Tracking Design

## Core Model Enhancement

```rust
// Enhanced StudySession with time tracking states
#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum StudySession {
    NotStarted(NotStartedStudySession),
    Active(ActiveStudySession), 
    Paused(PausedStudySession),
    Completed(CompletedStudySession),
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct StudySessionData {
    pub id: String,
    pub study_id: String,
    pub session_id: String,
    pub score: Option<u32>,
    pub notes: Option<String>,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct NotStartedStudySession {
    pub data: StudySessionData,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ActiveStudySession {
    pub data: StudySessionData,
    pub start_time: String,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct PausedStudySession {
    pub data: StudySessionData,
    pub start_time: String,
    pub elapsed_time: i64, // seconds
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct CompletedStudySession {
    pub data: StudySessionData,
    pub start_time: String,
    pub end_time: String,
    pub total_time: i64, // seconds
}
```

## Model State Management

```rust
// Add to Model
pub struct Model {
    // ... existing fields
    pub active_study_session_id: Option<String>,
}

// Core business rules
pub fn start_study_session(
    study_session_id: &str, 
    timestamp: String, 
    model: &mut Model
) -> Result<(), StudySessionError> {
    // Ensure only one study session can be active at a time
    if let Some(current_active_id) = &model.active_study_session_id {
        if current_active_id != study_session_id {
            // Auto-pause the currently active study session
            pause_study_session(current_active_id, timestamp.clone(), model)?;
        }
    }
    
    // Start the requested study session
    if let Some(study_session) = find_study_session_mut(study_session_id, model) {
        study_session.start(timestamp)?;
        model.active_study_session_id = Some(study_session_id.to_string());
        Ok(())
    } else {
        Err(StudySessionError::NotFound)
    }
}
```

## Events

```rust
#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum StudySessionEvent {
    // ... existing events
    
    // Time tracking events
    StartStudySession(String), // study_session_id
    PauseStudySession(String),
    ResumeStudySession(String), 
    CompleteStudySession(String),
    
    // Convenience event - stops current, starts new
    SwitchToStudy {
        session_id: String,
        study_id: String, 
    },
}
```

## iOS App Integration

### Timer View Model
```swift
class StudyTimerViewModel: ObservableObject {
    @Published var activeStudySession: StudySession?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isActive: Bool = false
    
    private var timer: Timer?
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let activeSession = self.activeStudySession,
               case .active(let data) = activeSession {
                self.elapsedTime = Date().timeIntervalSince(data.startTime)
            }
        }
    }
}
```

### Study List UI
```swift
struct StudyListView: View {
    @StateObject var viewModel: StudyTimerViewModel
    
    var body: some View {
        List(studies) { study in
            StudyRowView(
                study: study,
                isActive: viewModel.activeStudySession?.studyId == study.id,
                onTap: { 
                    // Switch to this study
                    core.update(.studySession(.switchToStudy(
                        sessionId: currentSessionId,
                        studyId: study.id
                    )))
                }
            )
        }
        .overlay(alignment: .bottom) {
            if let activeSession = viewModel.activeStudySession {
                ActiveStudyTimerView(
                    session: activeSession,
                    elapsedTime: viewModel.elapsedTime
                )
            }
        }
    }
}
```

## Server API Endpoints

```rust
// New endpoints for study session time tracking
POST /api/study-sessions/{id}/start
POST /api/study-sessions/{id}/pause  
POST /api/study-sessions/{id}/resume
POST /api/study-sessions/{id}/complete

// Switch active study (stops current, starts new)
POST /api/sessions/{session_id}/switch-study
{
    "study_id": "study-123"
}

// Get active study session
GET /api/sessions/{session_id}/active-study
```

## Database Schema Changes

```sql
-- Enhance study_sessions table
ALTER TABLE study_sessions ADD COLUMN state VARCHAR(20) DEFAULT 'not_started';
ALTER TABLE study_sessions ADD COLUMN start_time TIMESTAMPTZ;
ALTER TABLE study_sessions ADD COLUMN end_time TIMESTAMPTZ;  
ALTER TABLE study_sessions ADD COLUMN elapsed_time INTEGER DEFAULT 0; -- seconds
ALTER TABLE study_sessions ADD COLUMN notes TEXT;

-- Track active study session per practice session
ALTER TABLE practice_sessions ADD COLUMN active_study_session_id UUID REFERENCES study_sessions(id);
```

## Key Benefits

### Type Safety ✅
- Invalid state transitions caught at compile time
- No possibility of multiple active studies
- Clear state management

### User Experience ✅  
- Visual indication of active study
- Seamless switching between studies
- Automatic pause/resume of timing

### Performance ✅
- Efficient state tracking
- Minimal server round-trips
- Optimistic updates with background sync

### Analytics ✅
- Detailed time tracking per study
- Historical practice patterns
- Progress visualization

## Implementation Order

1. **Core Model Changes** - Enhance StudySession with states
2. **Event Handling** - Add time tracking events  
3. **iOS UI** - Timer view and study switching
4. **Server API** - New endpoints for time tracking
5. **Database Migration** - Schema updates

This approach leverages your existing architecture patterns while adding the time tracking functionality you need!