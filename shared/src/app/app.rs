            sessions: model.sessions.iter().map(|s| {
                crate::app::session::PracticeSessionView {
                    id: s.id.clone(),
                    goal_ids: s.goal_ids.clone(),
                    intention: s.intention.clone(),
                    state: s.state.clone(),
                    notes: s.notes.clone(),
                    exercise_records: s.exercise_records.clone(),
                    duration: s.duration(),
                    start_time: s.start_time().map(|t| t.to_string()),
                    pause_time: s.pause_time().map(|t| t.to_string()),
                    end_time: s.end_time().map(|t| t.to_string()),
                }
            }).collect(), 