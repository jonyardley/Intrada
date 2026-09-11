import SharedTypes
import SwiftUI

/// Post-session review (the player's Summary) — the celebration beat. Renders the
/// core's `SummaryView`: headline, an optional mastery toast, the recap
/// of what was played (per-item 1–10 scores), a whole-session note, an overall
/// session score (1–10), then Save (persists + returns to Idle) or Discard.
/// Reached after the last item.
struct SessionSummaryScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.marker) private var marker
  @State private var note = ""
  @State private var entryNotes: [String: String] = [:]
  @State private var expandedEntryId: String?
  @FocusState private var focusedEntryId: String?
  @State private var confirmingDiscard = false

  private var summary: SummaryView? { store.viewModel?.summary }

  var body: some View {
    ZStack {
      PaperBackground()
      if let summary {
        ScrollView {
          VStack(alignment: .leading, spacing: IntradaSpacing.section) {
            headline(summary).fadeUp(0)
            if let toast = topMover(summary) {
              MasteryDeltaToast(
                title: "\(toast.itemTitle) moved up",
                subtitle: nil,
                was: Int(toast.previousScore ?? 0),
                now: Int(toast.currentScore)
              )
              .fadeUp(1)
            }
            recap(summary).fadeUp(2)
            if let intention = summary.sessionIntention, !intention.isEmpty {
              intentionEcho(intention).fadeUp(3)
            }
            noteSection.fadeUp(4)
            sessionScoreRow(summary).fadeUp(5)
            controls.fadeUp(6)
          }
          .padding(.horizontal, IntradaSpacing.card)
          .padding(.top, IntradaSpacing.card)
          .padding(.bottom, IntradaSpacing.card)
        }
      }
    }
    // The recap otherwise scrolls under the status bar with nothing behind it (#1620).
    .safeAreaInset(edge: .top, spacing: 0) { header }
    .onAppear {
      note = summary?.notes ?? ""
    }
    .alert("Discard this session?", isPresented: $confirmingDiscard) {
      Button("Discard", role: .destructive) { store.send(.session(.discardSession)) }
      Button("Keep", role: .cancel) {}
    } message: {
      Text("This practice won't be saved.")
    }
  }

  // ── Header ──

  private var header: some View {
    VStack(spacing: 0) {
      Text("Session complete")
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.vertical, IntradaSpacing.controlGap)
      Rectangle().fill(IntradaColor.divider).frame(height: 1)
    }
    .background(IntradaColor.paperTop)
  }

  // ── Intention echo ──

  private func intentionEcho(_ intention: String) -> some View {
    HStack(alignment: .top, spacing: IntradaSpacing.controlGap) {
      Image(systemName: "quote.opening")
        .font(.system(size: 15))
        .foregroundStyle(marker)
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow("Your intention", tint: IntradaColor.celebrationInk)
        Text("“\(intention)”")
          .font(IntradaFont.cardTitle(15.5)).italic()
          .foregroundStyle(IntradaColor.celebrationInk)
      }
    }
    .padding(IntradaSpacing.cardCompact)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LinearGradient.celebration)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .accessibilityElement(children: .combine)
  }

  // ── Headline ──

  private func headline(_ summary: SummaryView) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(summary.totalDurationDisplay)
        .font(IntradaFont.pageTitle(34))
        .foregroundStyle(IntradaColor.ink)
      Text(headlineSubtitle(summary))
        .font(IntradaFont.subtitle)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func headlineSubtitle(_ summary: SummaryView) -> String {
    let done = summary.entries.filter { $0.status == .completed }.count
    let base = "\(done) of \(summary.entries.count)"
    return summary.completionStatus == .endedEarly ? "\(base) · ended early" : base
  }

  private func topMover(_ summary: SummaryView) -> ScoreChange? {
    guard let changes = store.viewModel?.analytics?.scoreChanges else { return nil }
    let titles = Swift.Set(summary.entries.map(\.itemTitle))
    return
      changes
      .filter { titles.contains($0.itemTitle) && $0.delta > 0 }
      .max { $0.delta < $1.delta }
  }

  // ── Recap ──

  private func recap(_ summary: SummaryView) -> some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("What you played")
      VStack(spacing: 0) {
        ForEach(Array(summary.entries.enumerated()), id: \.element.id) { index, entry in
          row(entry)
          if index < summary.entries.count - 1 {
            Rectangle().fill(IntradaColor.hairline).frame(height: 1)
          }
        }
      }
    }
  }

  private func row(_ entry: SetlistEntryView) -> some View {
    let unfinished = entry.status == .notAttempted
    return VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      HStack(spacing: 11) {
        dot(entry, unfinished: unfinished)
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.itemTitle)
            .font(IntradaFont.bodyMedium)
            .foregroundStyle(IntradaColor.ink)
          Text(metaLine(entry, unfinished: unfinished))
            .font(IntradaFont.micro)
            .foregroundStyle(IntradaColor.inkFaint)
          if let aim = entry.intention, !aim.isEmpty {
            Text("“\(aim)”")
              .font(IntradaFont.micro).italic()
              .foregroundStyle(IntradaColor.inkFaint)
          }
        }
        Spacer()
        if !unfinished {
          Text(entry.durationDisplay)
            .font(IntradaFont.meta)
            .monospacedDigit()
            .foregroundStyle(IntradaColor.inkSecondary)
        }
      }
      if entry.status == .completed {
        scoreRow(entry)
      }
      if !unfinished {
        noteRow(entry)
      }
    }
    .padding(.vertical, IntradaSpacing.cardCompact)
    .opacity(unfinished ? 0.5 : 1)
  }

  // A written note stays on the row: a note the musician cannot see again is
  // admin rather than reflection (T7).
  @ViewBuilder
  private func noteRow(_ entry: SetlistEntryView) -> some View {
    let written = entry.notes ?? ""
    Group {
      if expandedEntryId == entry.id {
        noteField(entry)
      } else if written.isEmpty {
        Button("Add a note") { expand(entry) }
          .font(IntradaFont.micro)
          .foregroundStyle(IntradaColor.accent)
          .frame(minHeight: 44, alignment: .leading)
          .contentShape(Rectangle())
          .accessibilityLabel("Add a note for \(entry.itemTitle)")
      } else {
        Button {
          expand(entry)
        } label: {
          Text(written)
            .font(IntradaFont.micro)
            .foregroundStyle(IntradaColor.inkSecondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Note for \(entry.itemTitle)")
        .accessibilityValue(written)
        .accessibilityHint("Edit this note")
      }
    }
    .padding(.leading, 19)
  }

  private func noteField(_ entry: SetlistEntryView) -> some View {
    TextField(
      "Anything worth remembering",
      text: Binding(
        get: { entryNotes[entry.id] ?? "" },
        set: { entryNotes[entry.id] = $0 }
      ),
      axis: .vertical
    )
    .lineLimit(2...4)
    .font(IntradaFont.field)
    .foregroundStyle(IntradaColor.ink)
    .padding(IntradaSpacing.cardCompact)
    .cardSurface(cornerRadius: IntradaRadius.control)
    .focused($focusedEntryId, equals: entry.id)
    .accessibilityLabel("Note for \(entry.itemTitle)")
    .onChange(of: entryNotes[entry.id]) { _, value in
      // Only while still in Summary, and only for a real change, or teardown
      // fires a core error on an identical round-trip.
      guard summary != nil else { return }
      let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let next = trimmed.isEmpty ? nil : trimmed
      guard next != entry.notes else { return }
      // A refusal (over-long note) surfaces on RootView's banner; the field
      // must not keep showing text the core rejected.
      let before = store.viewModel?.errorSeq
      store.send(.session(.updateEntryNotes(entryId: entry.id, notes: next)))
      if store.viewModel?.errorSeq != before {
        entryNotes[entry.id] = entry.notes ?? ""
      }
    }
  }

  private func expand(_ entry: SetlistEntryView) {
    entryNotes[entry.id] = entry.notes ?? ""
    withAnimation(reduceMotion ? nil : IntradaMotion.standard) { expandedEntryId = entry.id }
    focusedEntryId = entry.id
  }

  @ViewBuilder
  private func dot(_ entry: SetlistEntryView, unfinished: Bool) -> some View {
    if unfinished {
      Circle()
        .strokeBorder(IntradaColor.figureMuted, lineWidth: 1.5)
        .frame(width: 8, height: 8)
    } else {
      Circle().fill(entry.itemType.accent).frame(width: 8, height: 8)
    }
  }

  private func metaLine(_ entry: SetlistEntryView, unfinished: Bool) -> String {
    if unfinished { return "Saved for next time" }
    var parts = [entry.itemType.label]
    if let tempo = entry.achievedTempo { parts.append("\(tempo) bpm") }
    return parts.joined(separator: " · ")
  }

  private func scoreRow(_ entry: SetlistEntryView) -> some View {
    ScoreSelector(
      score: entry.score.map(Int.init) ?? 0,
      accessibilityLabel: "Mark for \(entry.itemTitle)"
    ) { next in
      store.send(.session(.updateEntryScore(entryId: entry.id, score: next)))
    }
    .padding(.leading, 19)
  }

  private func sessionScoreRow(_ summary: SummaryView) -> some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Text("Overall")
        .font(IntradaFont.metaMedium)
        .foregroundStyle(IntradaColor.inkSecondary)
      ScoreSelector(
        score: summary.sessionScore.map(Int.init) ?? 0,
        accessibilityLabel: "Overall session mark"
      ) { next in
        store.send(.session(.updateSessionScore(score: next)))
      }
    }
  }

  // ── Note + controls ──

  private var noteSection: some View {
    TextField(
      "A note on the whole session…", text: $note, axis: .vertical
    )
    .lineLimit(2...4)
    .font(IntradaFont.field)
    .foregroundStyle(IntradaColor.ink)
    .padding(IntradaSpacing.cardCompact)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.card)
        .stroke(IntradaColor.hairline, lineWidth: 1)
    )
    .onChange(of: note) { _, value in
      // Push real edits only, and only while still in Summary — avoids an
      // identical round-trip on the seeded value and a "not in summary" core
      // error if the field settles during teardown.
      guard summary != nil else { return }
      let trimmed = value.isEmpty ? nil : value
      guard trimmed != summary?.notes else { return }
      store.send(.session(.updateSessionNotes(notes: trimmed)))
    }
  }

  private var controls: some View {
    VStack(spacing: 10) {
      Button {
        store.send(.session(.saveSession(now: SessionClock.nowRFC3339())))
      } label: {
        Text("Save session")
          .font(IntradaFont.button)
          .foregroundStyle(IntradaColor.onMarker)
          .frame(maxWidth: .infinity)
          .padding(.vertical, IntradaSpacing.row)
          .background(marker)
          .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
      }
      .buttonStyle(PressRebound())
      Button("Discard") { confirmingDiscard = true }
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
  }
}

#if DEBUG
  #Preview("Completed") {
    SessionSummaryScreen().environment(Store.previewSummary)
  }

  #Preview("With intention") {
    SessionSummaryScreen().environment(Store.previewSummaryWithReflection)
  }

  #Preview("Ended early") {
    SessionSummaryScreen().environment(Store.previewSummaryEndedEarly)
  }
#endif
