import SharedTypes
import SwiftUI

/// Every piece an exercise serves, in one card (#1363): links and practice
/// history merged, one row each, always present — so an exercise that serves no
/// piece says "On its own" rather than showing nothing.
struct UsedInCard: View {
  let usage: [ExerciseUsageView]
  let locale: Locale
  let calendar: Calendar
  let onLink: (String) -> Void
  let onLinkAPiece: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      SectionHeader(title: "Used in", caption: pieceCountCaption)
      VStack(spacing: 0) {
        if usage.isEmpty {
          emptyState
        } else {
          ForEach(Array(usage.enumerated()), id: \.offset) { index, row in
            if index > 0 {
              HairlineDivider()
            }
            UsedInRow(
              usage: row, locale: locale, calendar: calendar,
              onLink: linkAction(for: row))
          }
        }
        HairlineDivider()
        linkAPieceFooter
      }
      .cardSurface()
    }
  }

  private var pieceCountCaption: String? {
    let pieces = usage.filter { $0.piece != nil && !$0.pieceRemoved }.count
    guard pieces > 0 else { return nil }
    return "\(pieces) \(pieces == 1 ? "piece" : "pieces")"
  }

  /// Only a piece you have practised alongside but never declared gets the
  /// button: the fact is already true, the button turns it into an intent.
  private func linkAction(for row: ExerciseUsageView) -> (() -> Void)? {
    guard let piece = row.piece, !row.linked, !row.pieceRemoved else { return nil }
    return { onLink(piece.id) }
  }

  private var emptyState: some View {
    VStack(spacing: IntradaSpacing.controlGap) {
      Text("On its own")
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.ink)
      Text("Not tied to a piece. Link one when it's serving a piece you're learning.")
        .font(IntradaFont.body)
        .foregroundStyle(IntradaColor.inkSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, IntradaSpacing.card)
    .padding(.vertical, IntradaSpacing.section)
    .background(IntradaColor.cardFill)
    .accessibilityElement(children: .combine)
  }

  private var linkAPieceFooter: some View {
    Button(action: onLinkAPiece) {
      Label("Link a piece", systemImage: "plus")
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, IntradaSpacing.cardCompact + IntradaSpacing.controlGap)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Link a piece to this exercise")
    .background(IntradaColor.cardFill)
  }
}

/// One row of `UsedInCard`. A live piece taps through; the "On its own" bucket
/// and pieces removed since they were practised (#1093, 2a) are inert.
struct UsedInRow: View {
  let usage: ExerciseUsageView
  let locale: Locale
  let calendar: Calendar
  var onLink: (() -> Void)? = nil

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var isStandalone: Bool { usage.piece == nil }
  private var navigable: Bool { usage.piece != nil && !usage.pieceRemoved }

  var body: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      // controlGap, not row, around the trailing controls: a row carrying both a
      // Link button and a chevron has little width left for the meta line.
      HStack(alignment: .top, spacing: IntradaSpacing.controlGap) {
        if navigable, let piece = usage.piece {
          NavigationLink(value: piece.id) { content }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(usage.spokenRow)
        } else {
          content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(usage.spokenRow)
        }
        if let onLink, !dynamicTypeSize.isAccessibilitySize {
          linkButton(onLink)
        }
        if navigable {
          Image(systemName: "chevron.right")
            .imageScale(.small)
            .foregroundStyle(IntradaColor.inkFaint)
            .accessibilityHidden(true)
        }
      }
      // At accessibility text sizes the button beside the meta line leaves so
      // little width that words break mid-word, so it drops to its own line.
      if let onLink, dynamicTypeSize.isAccessibilitySize {
        linkButton(onLink)
      }
    }
    .padding(.vertical, IntradaSpacing.row)
    .padding(.horizontal, IntradaSpacing.card)
    .background(IntradaColor.cardFill)
  }

  // Stacked at accessibility sizes so a long title word doesn't break mid-word beside the ring (#1731).
  private var content: some View {
    let layout: AnyLayout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: IntradaSpacing.controlGap))
      : AnyLayout(HStackLayout(spacing: IntradaSpacing.row))
    return layout {
      // Decorative here: the ring's rest glyph and "not practised together yet"
      // are the same fact, and for a rated row the mark is already spoken by
      // `spokenRow` (#1468).
      ScoreRing(score: usage.latestScore.map(Int.init), size: 44)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(usage.rowTitle)
          .font(isStandalone ? IntradaFont.bodyMedium : IntradaFont.cardTitle())
          .foregroundStyle(usage.pieceRemoved ? IntradaColor.inkSecondary : IntradaColor.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text(usage.metaLine(locale: locale, calendar: calendar))
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contentShape(Rectangle())
  }

  private func linkButton(_ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text("Link")
        .font(IntradaFont.badge)
        .foregroundStyle(IntradaColor.accent)
        // 10/5 are capsule-specific insets, below the token scale floor.
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: IntradaRadius.badge)
            .fill(IntradaColor.surfaceSunken)
            .stroke(IntradaColor.divider, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Link \(usage.rowTitle) to this exercise")
  }
}

#if DEBUG
  #Preview("Used in — every row state") {
    ZStack {
      PaperBackground()
      NavigationStack {
        ScrollView {
          UsedInCard(
            usage: LibraryItemView.previewExerciseUsedIn.usedIn,
            locale: Locale(identifier: "en_GB"), calendar: .current,
            onLink: { _ in }, onLinkAPiece: {}
          )
          .padding(IntradaSpacing.card)
        }
      }
    }
  }

  #Preview("Used in — on its own") {
    ZStack {
      PaperBackground()
      UsedInCard(
        usage: [], locale: Locale(identifier: "en_GB"), calendar: .current,
        onLink: { _ in }, onLinkAPiece: {}
      )
      .padding(IntradaSpacing.card)
    }
  }
#endif
