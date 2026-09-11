import SharedTypes
import SwiftUI

/// A "was → now" mastery row on Progress. The now-figure is success green; the
/// was-figure is muted. Pairs with `analytics.scoreChanges` (was = previousScore,
/// now = currentScore). A newly-scored item (`was == nil`) shows just the figure.
struct MasteryDelta: View {
  let title: String
  var subtitle: String?
  let was: Int?
  let now: Int
  // `ScoreChange` carries no item type — the leading dot defaults to the piece
  // accent; callers pass `.exercise` when they know it.
  var kind: ItemKind = .piece

  var body: some View {
    HStack(spacing: 11) {
      Circle()
        .fill(kind.accent)
        .frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(IntradaFont.cardTitle(14))
          .foregroundStyle(IntradaColor.ink)
        if let subtitle {
          Text(subtitle)
            .font(IntradaFont.micro)
            .foregroundStyle(IntradaColor.inkFaint)
        }
      }
      Spacer(minLength: IntradaSpacing.controlGap)
      HStack(spacing: 4) {
        if let was {
          Text("\(was)")
            .foregroundStyle(IntradaColor.figureMuted)
          Image(systemName: "arrow.right")
            .font(.system(size: 13))
            .foregroundStyle(IntradaColor.inkFaint)
        }
        Text("\(now)")
          .foregroundStyle(IntradaColor.success)
      }
      .font(IntradaFont.cardTitle(16))
    }
    .padding(.vertical, 11)
    .padding(.horizontal, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.card)
        .stroke(IntradaColor.hairline, lineWidth: 1)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    var parts = [title]
    if let subtitle { parts.append(subtitle) }
    if let was {
      parts.append("mastery up from \(was) to \(now)")
    } else {
      parts.append("mastery \(now)")
    }
    return parts.joined(separator: ", ")
  }
}

/// The celebration beat on the session summary: "Clair de Lune moved up
/// 3 → 4". Lands after the headline with a `toastIn` reveal (honours Reduce Motion).
struct MasteryDeltaToast: View {
  let title: String
  var subtitle: String?
  let was: Int
  let now: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.intradaMotionDisabled) private var motionDisabled
  @Environment(\.marker) private var marker
  @State private var shown = false

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: "sparkles")
        .font(.system(size: 17))
        .foregroundStyle(IntradaColor.onMarker)
        .frame(width: 34, height: 34)
        .background(marker, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.celebrationInk)
        if let subtitle {
          Text(subtitle)
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.celebrationInk.opacity(0.8))
        }
      }
      Spacer(minLength: IntradaSpacing.controlGap)
      HStack(spacing: 5) {
        Text("\(was)")
          .opacity(0.45)
        Image(systemName: "arrow.right")
          .font(.system(size: 15))
          .foregroundStyle(marker)
        Text("\(now)")
      }
      .font(IntradaFont.pageTitle(22))
      .foregroundStyle(IntradaColor.celebrationInk)
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LinearGradient.celebration)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .opacity(reveal ? 1 : 0)
    .scaleEffect(reveal ? 1 : 0.96)
    .offset(y: reveal ? 0 : -10)
    .onAppear {
      guard animates else { return }
      withAnimation(.easeOut(duration: 0.55).delay(0.5)) { shown = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title), mastery up from \(was) to \(now)")
  }

  private var animates: Bool {
    !reduceMotion && !motionDisabled && !UITestFlags.animationsDisabled
  }

  private var reveal: Bool { shown || !animates }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      VStack(spacing: IntradaSpacing.cardCompact) {
        MasteryDelta(
          title: "Clair de Lune", subtitle: "D♭ major · 3 weeks ago → now",
          was: 3, now: 4, kind: .piece)
        MasteryDelta(
          title: "Hanon No. 1", subtitle: "first time marked",
          was: nil, now: 3, kind: .exercise)
        MasteryDeltaToast(
          title: "Clair de Lune moved up", subtitle: "D♭ major mastery", was: 3, now: 4)
      }
      .padding(IntradaSpacing.card)
    }
  }
#endif
