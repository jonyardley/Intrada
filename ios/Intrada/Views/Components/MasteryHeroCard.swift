import SwiftUI

/// The Progress hero. At accessibility sizes the ring drops below the text: the
/// column beside it left the eyebrow too narrow for its own first word (#1471).
struct MasteryHeroCard: View {
  let mastery: Double
  let monthDelta: Double
  let itemsCovered: Int

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private let gutter: CGFloat = 18

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: gutter) {
          MasteryDial(value: mastery)
          summary
        }
      } else {
        HStack(spacing: gutter) {
          MasteryDial(value: mastery)
          summary
          Spacer(minLength: 0)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(gutter)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.panel))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.panel)
        .stroke(IntradaColor.hairline, lineWidth: 1))
  }

  private var summary: some View {
    VStack(alignment: .leading, spacing: 6) {
      Eyebrow("Overall mastery")
      HStack(spacing: 5) {
        Image(systemName: "chart.line.uptrend.xyaxis")
        Text("+\(monthDelta, specifier: "%.1f") this month")
      }
      .font(IntradaFont.metaMedium)
      .foregroundStyle(IntradaColor.success)
      Text("Climbing steadily across \(itemsCovered) pieces.")
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      MasteryHeroCard(mastery: 6.4, monthDelta: 1.2, itemsCovered: 5)
        .padding(IntradaSpacing.card)
    }
  }

  #Preview("Accessibility size") {
    ZStack {
      PaperBackground()
      MasteryHeroCard(mastery: 6.4, monthDelta: 1.2, itemsCovered: 5)
        .padding(IntradaSpacing.card)
    }
    .dynamicTypeSize(.accessibility3)
  }
#endif
