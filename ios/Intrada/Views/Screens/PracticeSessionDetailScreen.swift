import SharedTypes
import SwiftUI

/// A past session, opened from its card in Practice history. Read-only: marks
/// and notes are written during the session, on the summary screen, and this
/// is the record of what happened rather than a second place to edit it.
struct PracticeSessionDetailScreen: View {
  let session: PracticeSessionView

  @Environment(\.locale) private var locale
  @Environment(\.calendar) private var calendar
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    ScreenScaffold(
      title: session.dateDisplay(locale: locale, calendar: calendar), subtitle: subtitle
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.section) {
          if session.sessionScore != nil {
            sessionScoreCard
          }
          if let intention = session.sessionIntention, !intention.isEmpty {
            intentionEcho(intention)
          }
          if let notes = session.notes, !notes.isEmpty {
            noteCard(notes)
          }
          playedSection
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.top, IntradaSpacing.card)
        .padding(.bottom, IntradaSpacing.section)
      }
      .scrollEdgeShadow()
    }
  }

  private var subtitle: String {
    var parts = [session.totalDurationSummary, session.itemCountDisplay]
    if session.completionStatus == .endedEarly { parts.append("ended early") }
    return parts.joined(separator: " · ")
  }

  // ── Session score ──

  /// Same shape as the entry rows, so the same rule: the ring goes above the
  /// text at accessibility sizes rather than squeezing it into a column (#1471).
  private var sessionScoreCard: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
          ScoreRing(score: session.sessionScore.map(Int.init))
          sessionScoreText
        }
      } else {
        HStack(spacing: IntradaSpacing.card) {
          ScoreRing(score: session.sessionScore.map(Int.init))
          sessionScoreText
          Spacer(minLength: 0)
        }
      }
    }
    .padding(IntradaSpacing.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardSurface(cornerRadius: IntradaRadius.card)
    .accessibilityElement(children: .combine)
  }

  private var sessionScoreText: some View {
    VStack(alignment: .leading, spacing: 4) {
      Eyebrow("How it went")
      Text("Your mark for the session")
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
  }

  // ── Intention and note ──

  private func intentionEcho(_ intention: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Eyebrow("Your intention")
      Text("“\(intention)”")
        .font(IntradaFont.cardTitle(15.5)).italic()
        .foregroundStyle(IntradaColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func noteCard(_ notes: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Eyebrow("Your note")
      Text(notes)
        .font(IntradaFont.body)
        .foregroundStyle(IntradaColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  // ── What you played ──

  private var playedSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("What you played")
      VStack(spacing: 0) {
        ForEach(Array(session.entries.enumerated()), id: \.element.id) { index, entry in
          entryRow(entry)
          if index < session.entries.count - 1 {
            HairlineDivider()
          }
        }
      }
    }
  }

  /// The ring drops below the text at accessibility sizes: beside it, the
  /// column is narrow enough for the meta line to break mid-word (#1471).
  private func entryRow(_ entry: SetlistEntryView) -> some View {
    let played = entry.status == .completed
    let ring = played ? entry.scoreSummary.map(Int.init) : nil
    return Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
          entryText(entry)
          if let ring { ScoreRing(score: ring, size: 34) }
        }
      } else {
        HStack(alignment: .top, spacing: IntradaSpacing.cardCompact) {
          entryText(entry)
          Spacer(minLength: 0)
          if let ring { ScoreRing(score: ring, size: 34) }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, IntradaSpacing.cardCompact)
    .opacity(played ? 1 : 0.5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(entryAccessibilityLabel(entry))
  }

  private func entryText(_ entry: SetlistEntryView) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(entry.itemTitle)
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.ink)
      Text(entryMeta(entry))
        .font(IntradaFont.micro)
        .foregroundStyle(IntradaColor.inkFaint)
      if let notes = entry.notes, !notes.isEmpty {
        Text(notes)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
          .padding(.top, 2)
      }
    }
  }

  /// Facts only, and only the ones this session actually recorded: a tempo
  /// appears when it was measured, reps when there was a target.
  private func entryMeta(_ entry: SetlistEntryView) -> String {
    switch entry.status {
    case .notAttempted: return "Not played"
    case .skipped: return "Skipped"
    case .completed:
      // One line for the last play. #1739 Phase B gives each variation a row.
      var parts = [entry.itemType.label, entry.durationDisplay]
      let play = entry.plays.last
      if let tempo = play?.achievedTempo { parts.append("\(tempo) bpm") }
      if let target = play?.repTarget {
        parts.append("\(play?.repCount ?? 0) of \(target) reps")
      }
      return parts.joined(separator: " · ")
    }
  }

  private func entryAccessibilityLabel(_ entry: SetlistEntryView) -> String {
    var parts = [entry.itemTitle, entryMeta(entry)]
    if entry.status == .completed, let score = entry.scoreSummary {
      parts.append("marked \(score) out of 10")
    }
    if let notes = entry.notes, !notes.isEmpty { parts.append(notes) }
    return parts.joined(separator: ", ")
  }
}

#if DEBUG
  #Preview {
    NavigationStack {
      PracticeSessionDetailScreen(session: .previewCompleted)
        .environment(Store.previewPractice)
        .environment(\.calendar, PreviewCalendar.utc)
    }
  }

  #Preview("Ended early") {
    NavigationStack {
      PracticeSessionDetailScreen(session: .previewEndedEarly)
        .environment(Store.previewPractice)
        .environment(\.calendar, PreviewCalendar.utc)
    }
  }
#endif
