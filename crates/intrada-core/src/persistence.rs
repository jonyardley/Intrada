//! Local-first persistence — query/mutation operations the shell fulfils
//! against on-device SQLite. Unlike `AppEffect` (`Output = ()`), these
//! queries return data: the core's first effect with a real typed `Output`.

use chrono::{DateTime, Utc};
use crux_core::capability::Operation;
use crux_core::command::Command;
use serde::{Deserialize, Serialize};

use crate::app::{Effect, Event};
use crate::domain::item::Item;
use crate::domain::session::PracticeSession;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
// Boxing a variant would change the generated Swift type and the bridge wire,
// which is the same reason `app.rs` carries this allow.
#[allow(clippy::large_enum_variant)]
pub enum PersistenceOperation {
    LoadItems,
    SaveItem(Item),
    /// Upsert a batch atomically — the shell wraps all rows in one transaction,
    /// so a batch create (chart-to-scaffold commit) is all-or-nothing, never a
    /// half-linked piece with orphan exercises (#1106, invariant 5).
    SaveItems(Vec<Item>),
    /// Same `DateTime<Utc>` type as `Item::updated_at` so the tombstone bridges
    /// through the identical codec — byte-identical format under LWW, no drift.
    DeleteItem {
        id: String,
        deleted_at: DateTime<Utc>,
    },
    LoadSessions,
    SaveSession(PracticeSession),
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum PersistenceOutput {
    Items(Vec<Item>),
    Sessions(Vec<PracticeSession>),
    Ack,
    /// Local store failed the op — surfaced, not trusted as success (#816).
    Failed,
}

impl Operation for PersistenceOperation {
    type Output = PersistenceOutput;
}

pub fn load_items() -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::LoadItems).then_send(Event::StoreLoaded)
}

pub fn save_item(item: Item) -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::SaveItem(item)).then_send(Event::StoreWritten)
}

pub fn save_items(items: Vec<Item>) -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::SaveItems(items))
        .then_send(Event::StoreWritten)
}

pub fn delete_item(id: String, deleted_at: DateTime<Utc>) -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::DeleteItem { id, deleted_at })
        .then_send(Event::StoreWritten)
}

pub fn load_sessions() -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::LoadSessions)
        .then_send(Event::SessionsStoreLoaded)
}

pub fn save_session(session: PracticeSession) -> Command<Effect, Event> {
    Command::request_from_shell(PersistenceOperation::SaveSession(session))
        .then_send(Event::SessionStoreWritten)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::item::ItemKind;
    use crate::model::Model;
    use crux_core::App;

    fn sample_item(id: &str) -> Item {
        let now = chrono::Utc::now();
        Item {
            id: id.to_string(),
            title: "Etude".to_string(),
            kind: ItemKind::Piece,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            created_at: now,
            updated_at: now,
            linked_exercise_ids: vec![],
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        }
    }

    #[test]
    fn load_items_requests_the_load_operation() {
        let mut cmd = load_items();
        let op = cmd
            .effects()
            .find_map(|e| match e {
                Effect::Persistence(req) => Some(req.operation.clone()),
                _ => None,
            })
            .expect("expected a Persistence effect");
        assert_eq!(op, PersistenceOperation::LoadItems);
    }

    #[test]
    fn hydrate_from_store_emits_a_load_effect() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::HydrateFromStore, &mut model);
        assert!(cmd
            .effects()
            .any(|e| matches!(e, Effect::Persistence(req) if req.operation == PersistenceOperation::LoadItems)));
    }

    #[test]
    fn store_loaded_items_replaces_model_items() {
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("stale")],
            ..Default::default()
        };
        let _ = app.update(
            Event::StoreLoaded(PersistenceOutput::Items(vec![sample_item("fresh")])),
            &mut model,
        );
        assert_eq!(model.items.len(), 1);
        assert_eq!(model.items[0].id, "fresh");
    }

    #[test]
    fn store_loaded_failed_surfaces_an_error() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::StoreLoaded(PersistenceOutput::Failed), &mut model);
        assert!(
            model.last_error.is_some(),
            "a failed read must surface an error"
        );
        assert!(!cmd.effects().any(|e| matches!(e, Effect::Persistence(_))));
    }

    #[test]
    fn store_written_failed_surfaces_and_rehydrates() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::StoreWritten(PersistenceOutput::Failed), &mut model);
        assert!(
            model.last_error.is_some(),
            "a failed write must surface an error"
        );
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if req.operation == PersistenceOperation::LoadItems)));
    }

    #[test]
    fn store_written_ack_is_a_noop() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::StoreWritten(PersistenceOutput::Ack), &mut model);
        assert!(model.last_error.is_none());
        assert!(!cmd.effects().any(|e| matches!(e, Effect::Persistence(_))));
    }

    #[test]
    fn store_loaded_ack_leaves_items_untouched() {
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("keep")],
            ..Default::default()
        };
        let _ = app.update(Event::StoreLoaded(PersistenceOutput::Ack), &mut model);
        assert_eq!(model.items.len(), 1);
        assert_eq!(model.items[0].id, "keep");
    }

    // ── Builders ────────────────────────────────────────────────────────

    fn has_save(cmd: &mut Command<Effect, Event>, id: &str) -> bool {
        cmd.effects().any(|e| {
            matches!(e, Effect::Persistence(req)
                if matches!(&req.operation, PersistenceOperation::SaveItem(item) if item.id == id))
        })
    }

    fn has_persistence(cmd: &mut Command<Effect, Event>) -> bool {
        cmd.effects().any(|e| matches!(e, Effect::Persistence(_)))
    }

    fn has_delete(cmd: &mut Command<Effect, Event>, id: &str) -> bool {
        cmd.effects().any(|e| {
            matches!(e, Effect::Persistence(req)
            if matches!(&req.operation, PersistenceOperation::DeleteItem { id: op_id, .. } if op_id == id))
        })
    }

    #[test]
    fn save_item_requests_a_save_op() {
        let mut cmd = save_item(sample_item("p1"));
        assert!(has_save(&mut cmd, "p1"));
    }

    #[test]
    fn save_items_requests_one_batch_op_with_all_rows() {
        let mut cmd = save_items(vec![sample_item("a"), sample_item("b")]);
        let ids = cmd
            .effects()
            .find_map(|e| match e {
                Effect::Persistence(req) => match req.operation {
                    PersistenceOperation::SaveItems(items) => {
                        Some(items.iter().map(|i| i.id.clone()).collect::<Vec<_>>())
                    }
                    _ => None,
                },
                _ => None,
            })
            .expect("expected one SaveItems persistence effect");
        assert_eq!(ids, vec!["a".to_string(), "b".to_string()]);
    }

    #[test]
    fn delete_item_requests_a_delete_op() {
        let mut cmd = delete_item("gone".to_string(), chrono::Utc::now());
        assert!(has_delete(&mut cmd, "gone"));
    }

    #[test]
    fn delete_stamps_the_delete_instant() {
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("p1")],
            ..Default::default()
        };
        let before = chrono::Utc::now();
        let mut cmd = app.update(
            Event::Item(crate::domain::item::ItemEvent::Delete {
                id: "p1".to_string(),
            }),
            &mut model,
        );
        let after = chrono::Utc::now();

        let deleted_at = cmd
            .effects()
            .find_map(|e| match e {
                Effect::Persistence(req) => match req.operation {
                    PersistenceOperation::DeleteItem { deleted_at, .. } => Some(deleted_at),
                    _ => None,
                },
                _ => None,
            })
            .expect("a DeleteItem persistence op");
        // Core stamps the delete instant (DateTime<Utc>, same type as updated_at).
        assert!(deleted_at >= before && deleted_at <= after);
    }

    // ── Local-first mode: writes persist locally, no HTTP ───────────────

    fn create_item() -> crate::domain::types::CreateItem {
        crate::domain::types::CreateItem {
            title: "New".into(),
            kind: ItemKind::Piece,
            composer: Some("Chopin".into()), // pieces require a composer (validation)
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        }
    }

    #[test]
    fn add_persists_with_the_client_ulid() {
        use crate::domain::item::ItemEvent;
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::Item(ItemEvent::Add(create_item())), &mut model);
        let id = model.items[0].id.clone();
        assert!(
            has_save(&mut cmd, &id),
            "create persists with the client ulid"
        );
    }

    #[test]
    fn update_persists_the_edited_row() {
        use crate::domain::item::ItemEvent;
        use crate::domain::types::UpdateItem;
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("p1")],
            ..Default::default()
        };
        let input = UpdateItem {
            title: Some("Renamed".into()),
            kind: None,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: None,
            priority: None,
        };
        let mut cmd = app.update(
            Event::Item(ItemEvent::Update {
                id: "p1".into(),
                input,
            }),
            &mut model,
        );
        assert!(has_save(&mut cmd, "p1"));
    }

    #[test]
    fn delete_persists_a_tombstone() {
        use crate::domain::item::ItemEvent;
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("p1")],
            ..Default::default()
        };
        let mut cmd = app.update(
            Event::Item(ItemEvent::Delete { id: "p1".into() }),
            &mut model,
        );
        assert!(has_delete(&mut cmd, "p1"));
    }

    #[test]
    fn a_failed_delete_rolls_back_via_store_reload() {
        // End-to-end rollback (#834): an optimistic delete whose store write
        // fails must never be a silent success (invariant #5) — it surfaces an
        // error and reloads from the store, which still holds the row the
        // failed write never removed.
        use crate::domain::item::ItemEvent;
        let app = crate::app::Intrada;
        let mut model = Model {
            items: vec![sample_item("p1")],
            ..Default::default()
        };
        let mut cmd = app.update(
            Event::Item(ItemEvent::Delete { id: "p1".into() }),
            &mut model,
        );
        assert!(
            model.items.is_empty(),
            "delete optimistically removes the row"
        );
        assert!(has_delete(&mut cmd, "p1"));

        let mut cmd = app.update(Event::StoreWritten(PersistenceOutput::Failed), &mut model);
        assert!(
            model.last_error.is_some(),
            "a failed delete must surface an error, not vanish silently"
        );
        assert!(
            cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
                if req.operation == PersistenceOperation::LoadItems)),
            "a failed write reloads from the store to roll back"
        );

        let _ = app.update(
            Event::StoreLoaded(PersistenceOutput::Items(vec![sample_item("p1")])),
            &mut model,
        );
        assert_eq!(
            model.items.len(),
            1,
            "the rolled-back delete restores the row"
        );
        assert_eq!(model.items[0].id, "p1");
    }

    #[test]
    fn a_successful_write_clears_the_dismiss_mute() {
        use crate::domain::item::ItemEvent;
        let app = crate::app::Intrada;
        let mut model = Model::default();
        model.dismiss_error();
        let _ = app.update(Event::Item(ItemEvent::Add(create_item())), &mut model);
        assert!(
            !model.error_muted,
            "a successful local write should un-mute"
        );
    }

    #[test]
    fn start_app_hydrates_from_store() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::StartApp, &mut model);
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if req.operation == PersistenceOperation::LoadItems)));
    }

    /// Offline-first invariant 1 (`.claude/rules/offline-first.md`): every step
    /// of the lifecycle (launch, create, update, delete) reaches the on-device
    /// store, so nothing the musician does lives only in memory.
    #[test]
    fn offline_invariant_lifecycle_reaches_the_store_at_every_step() {
        use crate::domain::item::ItemEvent;
        use crate::domain::types::UpdateItem;
        let app = crate::app::Intrada;
        let mut model = Model::default();

        let mut launch = app.update(Event::StartApp, &mut model);
        assert!(has_persistence(&mut launch), "launch");

        let mut add = app.update(Event::Item(ItemEvent::Add(create_item())), &mut model);
        assert!(has_persistence(&mut add), "create");
        let id = model.items[0].id.clone();

        let input = UpdateItem {
            title: Some("Renamed".into()),
            kind: None,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: None,
            priority: None,
        };
        let mut update = app.update(
            Event::Item(ItemEvent::Update {
                id: id.clone(),
                input,
            }),
            &mut model,
        );
        assert!(has_persistence(&mut update), "update");

        let mut delete = app.update(Event::Item(ItemEvent::Delete { id }), &mut model);
        assert!(has_persistence(&mut delete), "delete");
    }

    // ── Sessions ────────────────────────────────────────────────────────

    fn sample_session(id: &str) -> PracticeSession {
        let now = chrono::Utc::now();
        PracticeSession {
            id: id.to_string(),
            entries: vec![],
            session_notes: None,
            started_at: now,
            completed_at: now,
            total_duration_secs: 0,
            completion_status: crate::domain::session::CompletionStatus::Completed,
            session_score: None,
        }
    }

    #[test]
    fn save_session_requests_a_save_op() {
        let mut cmd = save_session(sample_session("s1"));
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if matches!(&req.operation, PersistenceOperation::SaveSession(s) if s.id == "s1"))));
    }

    #[test]
    fn load_sessions_requests_the_load_operation() {
        let mut cmd = load_sessions();
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if req.operation == PersistenceOperation::LoadSessions)));
    }

    #[test]
    fn sessions_store_loaded_replaces_model_sessions() {
        let app = crate::app::Intrada;
        let mut model = Model {
            sessions: vec![sample_session("stale")],
            ..Default::default()
        };
        let _ = app.update(
            Event::SessionsStoreLoaded(PersistenceOutput::Sessions(vec![sample_session("fresh")])),
            &mut model,
        );
        assert_eq!(model.sessions.len(), 1);
        assert_eq!(model.sessions[0].id, "fresh");
    }

    #[test]
    fn start_app_also_loads_sessions() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(Event::StartApp, &mut model);
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if req.operation == PersistenceOperation::LoadSessions)));
    }

    #[test]
    fn session_store_written_failed_reloads_sessions() {
        let app = crate::app::Intrada;
        let mut model = Model::default();
        let mut cmd = app.update(
            Event::SessionStoreWritten(PersistenceOutput::Failed),
            &mut model,
        );
        assert!(model.last_error.is_some());
        assert!(cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
            if req.operation == PersistenceOperation::LoadSessions)));
    }
}
