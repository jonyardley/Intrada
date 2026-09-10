import SharedTypes
import SwiftUI

/// The Practice hero when the core has something to suggest (#1082): the piece,
/// why it is being suggested, its two or three items with their reasons, and one
/// `Start · N min`. Every reason string is the core's — the shell renders, never
/// composes (design-principles T15).
struct UpNextHero: View {
  let suggestion: SuggestedSession
  let onStart: () -> Void
  let onBuildOwn: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.row) {
      headline
      itemList
      startButton
      buildOwnButton
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(IntradaSpacing.section)
    .background(LinearGradient.practiceHero)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.hero))
    .heroShadow()
    .accessibilityElement(children: .contain)
  }

  // Eyebrow, title, count and reason read as one sentence: split up, VoiceOver
  // announces "3 items · 15 min" detached from the piece it describes.
  private var headline: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      HStack(alignment: .firstTextBaseline) {
        Eyebrow("Up next", tint: IntradaColor.onAccent.opacity(0.7))
        Spacer(minLength: IntradaSpacing.controlGap)
        Text(countLabel)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.onAccent.opacity(0.7))
      }

      Text(suggestion.pieceTitle)
        .font(IntradaFont.pageTitle(27))
        .foregroundStyle(IntradaColor.paperTop)
        .lineLimit(3)
        .minimumScaleFactor(0.75)
        .fixedSize(horizontal: false, vertical: true)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        if suggestion.priority {
          Image(systemName: "star.fill")
            .font(.system(size: 11))
            .foregroundStyle(IntradaColor.onHeroStar)
        }
        Text(suggestion.reason)
          .font(IntradaFont.subtitle)
          .foregroundStyle(IntradaColor.onAccent.opacity(0.85))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(headlineLabel)
  }

  private var itemList: some View {
    VStack(spacing: 0) {
      ForEach(Array(suggestion.items.enumerated()), id: \.element.itemId) { index, item in
        if index > 0 {
          Rectangle()
            .fill(IntradaColor.paperTop.opacity(0.12))
            .frame(height: 1)
        }
        row(item)
      }
    }
    .padding(.horizontal, IntradaSpacing.cardCompact)
    .background(IntradaColor.paperTop.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.card)
        .strokeBorder(IntradaColor.paperTop.opacity(0.14), lineWidth: 1)
    )
  }

  private func row(_ item: SuggestedItem) -> some View {
    HStack(alignment: .top, spacing: IntradaSpacing.controlGap) {
      Circle()
        .fill(item.itemType.onHeroAccent)
        .frame(width: 7, height: 7)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 2) {
        Text(titleLine(item))
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.paperTop)
          .fixedSize(horizontal: false, vertical: true)
        Text(item.reason)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.onAccent.opacity(0.75))
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, IntradaSpacing.cardCompact)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(rowLabel(item))
  }

  private func titleLine(_ item: SuggestedItem) -> AttributedString {
    var line = AttributedString(item.itemTitle)
    guard let step = item.variantLabel else { return line }
    var suffix = AttributedString(" · step \(step)")
    suffix.foregroundColor = item.itemType.onHeroAccent
    line.append(suffix)
    return line
  }

  private var startButton: some View {
    Button(action: onStart) {
      HStack(spacing: IntradaSpacing.controlGap) {
        Image(systemName: "play.fill")
        Text("Start · \(suggestion.estimatedMinutes) min")
      }
      .font(IntradaFont.bodyMedium)
      .foregroundStyle(IntradaColor.accent)
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.row)
      .background(
        IntradaColor.playerBgTop, in: RoundedRectangle(cornerRadius: IntradaRadius.control))
    }
    .buttonStyle(PressRebound())
    .accessibilityLabel("Start practising")
    .accessibilityValue("\(itemCountLabel), about \(suggestion.estimatedMinutes) minutes")
  }

  private var buildOwnButton: some View {
    Button("Build my own instead", action: onBuildOwn)
      .font(IntradaFont.subtitle)
      .foregroundStyle(IntradaColor.onAccent.opacity(0.78))
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.controlGap)
      .accessibilityHint("Opens the session builder")
  }

  private var itemCountLabel: String {
    let count = suggestion.items.count
    return "\(count) item\(count == 1 ? "" : "s")"
  }

  private var countLabel: String {
    "\(itemCountLabel) · \(suggestion.estimatedMinutes) min"
  }

  private var headlineLabel: String {
    var parts = ["Up next", suggestion.pieceTitle]
    if let composer = suggestion.pieceSubtitle { parts.append(composer) }
    parts.append(spoken(suggestion.reason))
    parts.append(countLabel.replacingOccurrences(of: " · ", with: ", "))
    return parts.joined(separator: ", ")
  }

  private func rowLabel(_ item: SuggestedItem) -> String {
    var parts = [item.itemTitle]
    if let step = item.variantLabel { parts.append("step \(step)") }
    parts.append(item.itemType.label)
    parts.append(spoken(item.reason))
    return parts.joined(separator: ", ")
  }

  // VoiceOver reads the house separator as "middle dot"; commas are the pause
  // the sentence actually wants.
  private func spoken(_ reason: String) -> String {
    reason.replacingOccurrences(of: " · ", with: ", ")
  }
}

#if DEBUG
  #Preview("Starred") {
    ZStack {
      PaperBackground()
      UpNextHero(suggestion: .previewStarred, onStart: {}, onBuildOwn: {})
        .padding(IntradaSpacing.card)
    }
  }

  #Preview("Unstarred, never marked") {
    ZStack {
      PaperBackground()
      UpNextHero(suggestion: .previewFresh, onStart: {}, onBuildOwn: {})
        .padding(IntradaSpacing.card)
    }
  }
#endif
