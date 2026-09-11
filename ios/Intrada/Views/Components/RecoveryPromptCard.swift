import SharedTypes
import SwiftUI

/// The #962 crash-recovery prompt shown on the Practice tab when a
/// session-in-progress blob survives a relaunch.
struct RecoveryPromptCard: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale

  let session: ActiveSession
  /// Injected for deterministic snapshots; production passes "now".
  var referenceDate: Date = Date()
  let onResume: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("Session in progress", tint: IntradaColor.inkSecondary)

      Text("Pick up where you left off?")
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.ink)

      Text(meta)
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)

      HStack(spacing: IntradaSpacing.controlGap) {
        Button(action: onResume) {
          Label("Resume", systemImage: "play.fill")
            .font(IntradaFont.bodyMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, IntradaSpacing.cardCompact)
        }
        .buttonStyle(.borderedProminent)
        .tint(IntradaColor.accent)
        .accessibilityLabel("Resume the interrupted session")

        Button("Discard", action: onDiscard)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.inkSecondary)
          .padding(.horizontal, IntradaSpacing.cardCompact)
          .accessibilityLabel("Discard the interrupted session")
      }
    }
    .padding(IntradaSpacing.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .accessibilityElement(children: .contain)
  }

  private var meta: String {
    let position = min(Int(session.currentIndex) + 1, session.entries.count)
    let count = "\(position) of \(session.entries.count) items"
    guard let started = SessionClock.parseRFC3339(session.sessionStartedAt) else { return count }
    let formatter = DateFormatter()
    // An old blob saying just "9:02 AM" reads as today — show the date too.
    formatter.dateStyle = calendar.isDate(started, inSameDayAs: referenceDate) ? .none : .medium
    formatter.timeStyle = .short
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = locale
    return "\(count) · started \(formatter.string(from: started))"
  }
}
