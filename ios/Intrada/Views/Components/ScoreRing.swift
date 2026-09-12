import SwiftUI

struct ScoreRing: View {
  let score: Int?
  var size: CGFloat = 46
  /// Hero variant: an "OF 10" caption under the numeral (piece/exercise detail).
  var showsScale: Bool = false
  /// Mastered variant: fills with `accent` instead of the usual `masteryFill`.
  var solid: Bool = false
  /// Variation variant: renders this text (e.g. a key letter) instead of the
  /// numeral/rest glyph. Scales down and truncates for labels too long to fit.
  var labelOverride: String? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.intradaMotionDisabled) private var motionDisabled
  @State private var shown = false

  private var isUnrated: Bool { score == nil || score == 0 }
  private var clampedScore: Int { score.map { max(1, min(10, $0)) } ?? 0 }
  private var fraction: CGFloat { CGFloat(clampedScore) / 10 }
  private var lineWidth: CGFloat { max(3, size * 0.09) }

  private var animates: Bool {
    !reduceMotion && !motionDisabled && !UITestFlags.animationsDisabled
  }
  private var settled: Bool { shown || !animates }

  var body: some View {
    ZStack {
      Circle()
        .stroke(IntradaColor.masteryTrack, lineWidth: lineWidth)
      if !isUnrated {
        Circle()
          .trim(from: 0, to: settled ? fraction : 0)
          .stroke(
            solid ? IntradaColor.accent : IntradaColor.masteryFill,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
      VStack(spacing: size * 0.02) {
        if let labelOverride {
          Text(labelOverride)
            .font(IntradaFont.scoreNumeral(size * 0.33))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isUnrated ? IntradaColor.inkFaint : IntradaColor.ink)
        } else if isUnrated {
          // "Not yet played" reads as a rest (see EighthRestShape).
          EighthRestShape()
            .fill(IntradaColor.inkFaint)
            .frame(width: size * 0.45 * EighthRestShape.aspect, height: size * 0.45)
        } else {
          Text("\(clampedScore)")
            .font(IntradaFont.scoreNumeral(size * 0.36))
            .foregroundStyle(IntradaColor.ink)
          if showsScale {
            Text("OF 10")
              .font(IntradaFont.eyebrow)
              .kerning(0.5)
              .foregroundStyle(IntradaColor.inkFaint)
          }
        }
      }
    }
    .padding(lineWidth / 2)
    .frame(width: size, height: size)
    .onAppear {
      guard animates, !shown else { return }
      withAnimation(.easeOut(duration: IntradaMotion.countUpDuration)) { shown = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isUnrated ? "Not yet rated" : "Mark \(clampedScore) of 10")
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      HStack(spacing: 16) {
        ForEach([0, 1, 4, 7, 10], id: \.self) { ScoreRing(score: $0) }
        ScoreRing(score: nil)
      }
      .padding(IntradaSpacing.card)
    }
  }
#endif
