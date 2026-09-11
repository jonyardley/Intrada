import SwiftUI

/// The locked "paper / score" light theme (Pencil: *Mobile / Library — Light*).
/// Every colour, gradient, and type style the native shell draws traces back to
/// a token here — views never hard-code a hex value or raw `.system` font.
enum IntradaColor {
  static let paperTop = Color(hex: 0xF4F1E8)
  static let paperBottom = Color(hex: 0xEBE7D9)

  static let cardFill = Color(hex: 0xFCFAF3)
  static let surfaceSunken = Color(hex: 0xF0E7D6)
  static let hairline = Color(hex: 0xE5DECD)
  static let divider = Color(hex: 0xE0D9C8)

  static let ink = Color(hex: 0x2B2A26)
  static let inkSecondary = Color(hex: 0x6E6557)
  /// Eyebrow labels only — fails WCAG AA (2.9:1); metadata/body use inkSecondary.
  static let inkFaint = Color(hex: 0x9A927F)
  /// A dimmed glyph with no text of its own to fall back on (#1458): 3.29:1 on
  /// `cardFill`, clearing the 3:1 floor for non-text graphical objects
  /// (WCAG 1.4.11). Never for text — `inkFaint` already fails that.
  static let inkFaintIcon = Color(hex: 0x928A76)

  static let accent = Color(hex: 0x4C3FA6)
  static let onAccent = Color(hex: 0xF2EFE8)
  static let danger = Color(hex: 0xB3261E)
  /// The banner and whatever it points at wear the same wash, so the pair reads
  /// as one thing rather than two unrelated red surfaces (#1595).
  static let dangerWash = danger.opacity(0.10)
  static let dangerEdge = danger.opacity(0.25)
  static let shadow = Color.black.opacity(0.06)
  static let brandGradientStart = Color(hex: 0x6346E5)
  static let brandGradientEnd = Color(hex: 0x4C3FA6)

  static let tabBarFill = Color(hex: 0xEFEBDF)

  static let pieceBadgeBg = Color(hex: 0xE7E3F4)
  static let pieceBadgeFg = Color(hex: 0x4C3FA6)
  static let exerciseAccent = Color(hex: 0x9E7B33)
  static let exerciseBadgeBg = Color(hex: 0xF0E5CC)
  static let exerciseBadgeFg = Color(hex: 0x8A6A2E)

  // ── Engaging-refresh tokens ──
  /// Mastery gains, clean reps, trending-up. Reserved from `danger` (destructive).
  static let successTeal = Color(hex: 0x1F8A5B)
  /// Mastery is monochrome indigo — the *count* carries meaning (colour-blind
  /// safe); never recolour a meter/dial by level.
  static let masteryFill = Color(hex: 0x4C3FA6)
  static let masteryTrack = Color(hex: 0xE2DBC9)
  static let dialTrack = Color(hex: 0xEBE4D4)
  /// The Focus-player timer ring track — warmer than the mastery `dialTrack`.
  static let timerTrack = Color(hex: 0xE5DDCB)
  /// The Focus-player click while it is sounding — accent-tinted paper, opaque
  /// so the tempo steppers reveal beside it without ghosting.
  static let clickActiveBg = Color(hex: 0xE7E3F4)
  static let consistencyTrack = Color(hex: 0xDED5C1)
  /// A "missed" rep is taupe, never red — calm, not shaming.
  static let repMissedFg = Color(hex: 0x8A8170)
  static let repMissedBg = Color(hex: 0xEFEADC)
  static let repCleanFg = Color(hex: 0x1F8A5B)
  static let repCleanBg = Color(hex: 0xE7F1EB)
  static let repCleanBorder = Color(hex: 0xC9E2D3)
  /// Empty rep-slot ring + missed-button border.
  static let slotOutline = Color(hex: 0xDCD4C1)
  /// Dashed outline on full-width "+ Add …" rows.
  static let addDashOutline = Color(hex: 0xC9C0AC)
  /// The faded "was" number in a was→now delta.
  static let figureMuted = Color(hex: 0xB6AEC4)
  /// Not-yet days in the week picker.
  static let futureDay = Color(hex: 0xC9C0AC)
  static let inkFainter = Color(hex: 0xB0A892)
  // Focus-player warm radial backdrop.
  static let playerBgTop = Color(hex: 0xF7F4EC)
  static let playerBgMid = Color(hex: 0xEFEADC)
  static let playerBgBottom = Color(hex: 0xE7E2D2)
  // Practice one-tap hero (deep indigo).
  static let heroGradientTop = Color(hex: 0x5648B2)
  static let heroGradientMid = Color(hex: 0x43388F)
  static let heroGradientBottom = Color(hex: 0x392F7C)
  /// The type language lifted onto the indigo hero: the badge colours are tuned
  /// for paper and go muddy on it, so gold and indigo get a light-on-dark pair.
  /// Read `ItemKind.onHeroAccent`, not these directly.
  static let onHeroExercise = Color(hex: 0xE8D9A8)
  static let onHeroPiece = Color(hex: 0xC7BEEA)
  /// The priority star on the hero. `accent` is its colour on paper and is
  /// invisible on indigo; gold reads, and the star is the only thing wearing it
  /// that isn't an exercise.
  static let onHeroStar = Color(hex: 0xE8D9A8)
  // Session-summary gold celebration toast.
  static let celebrationBgTop = Color(hex: 0xF1E9D6)
  static let celebrationBgBottom = Color(hex: 0xECE0C6)
  static let celebrationBorder = Color(hex: 0xE6D6B0)
  static let celebrationInk = Color(hex: 0x7A6A3F)
  static let onExercise = Color(hex: 0xF6EFD8)
  /// The full-screen photo viewer's ground. Warm near-black from the ink family
  /// rather than paper: cream around a photograph tints how you read the page.
  static let viewerBackdrop = Color(hex: 0x1A1917)
}

extension LinearGradient {
  static let paper = LinearGradient(
    colors: [IntradaColor.paperTop, IntradaColor.paperBottom],
    startPoint: .top, endPoint: .bottom)

  static let brandBar = LinearGradient(
    colors: [IntradaColor.brandGradientStart, IntradaColor.brandGradientEnd],
    startPoint: .top, endPoint: .bottom)

  /// The session-summary celebration toast (CSS `120deg`).
  static let celebration = LinearGradient(
    colors: [IntradaColor.celebrationBgTop, IntradaColor.celebrationBgBottom],
    startPoint: .topLeading, endPoint: .bottomTrailing)

  static let exerciseBar = LinearGradient(
    colors: [IntradaColor.exerciseAccent, IntradaColor.exerciseBadgeFg],
    startPoint: .top, endPoint: .bottom)

  /// The Practice one-tap hero card (CSS `165deg` ≈ top-trailing → bottom-leading).
  static let practiceHero = LinearGradient(
    colors: [
      IntradaColor.heroGradientTop, IntradaColor.heroGradientMid,
      IntradaColor.heroGradientBottom,
    ],
    startPoint: .topTrailing, endPoint: .bottomLeading)

  /// Ring/dial strokes use the diagonal sweep `(0,0)→(1,1)` of the brand stops
  /// (buttons/bars use the vertical `brandBar` — match per element).
  static let ringSweep = LinearGradient(
    colors: [IntradaColor.brandGradientStart, IntradaColor.brandGradientEnd],
    startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension RadialGradient {
  /// The Focus-player warm cream wash — CSS `radial-gradient(120% 80% at 50% 22%)`.
  static let playerPaper = RadialGradient(
    colors: [
      IntradaColor.playerBgTop, IntradaColor.playerBgMid, IntradaColor.playerBgBottom,
    ],
    center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 440)
}

/// Semantic type styles: Source Serif 4 headings, Inter body/UI (bundled via
/// `IntradaFonts`). `relativeTo:` tracks Dynamic Type; weights use named-instance
/// PostScript names, not `.weight()`, which is synthetic over a variable axis.
enum IntradaFont {
  static func pageTitle(_ size: CGFloat = 32) -> Font {
    .custom(Serif.semibold, size: size, relativeTo: .largeTitle)
  }
  static func cardTitle(_ size: CGFloat = 17) -> Font {
    .custom(Serif.semibold, size: size, relativeTo: .title3)
  }
  /// The live session timer — the boldest *named* Inter instance (not a synthetic
  /// `.bold()` over the variable axis) at display size. Pair with `.monospacedDigit()`.
  static func timer(_ size: CGFloat = 56) -> Font {
    .custom(Inter.semibold, size: size, relativeTo: .largeTitle)
  }
  static func scoreNumeral(_ size: CGFloat) -> Font {
    .custom(Inter.semibold, size: size, relativeTo: .title3)
  }

  static let body = Font.custom(Inter.regular, size: 14, relativeTo: .subheadline)
  static let bodyMedium = Font.custom(Inter.medium, size: 15, relativeTo: .subheadline)
  static let subtitle = Font.custom(Inter.regular, size: 13, relativeTo: .footnote)
  static let meta = Font.custom(Inter.regular, size: 12, relativeTo: .caption)
  static let micro = Font.custom(Inter.regular, size: 10, relativeTo: .caption2)
  static let metaMedium = Font.custom(Inter.medium, size: 12, relativeTo: .caption)
  static let badge = Font.custom(Inter.semibold, size: 12, relativeTo: .caption)
  /// Uppercase section label (letter-spaced, `inkFaint`) — the eyebrow above
  /// every section on the refreshed screens.
  static let eyebrow = Font.custom(Inter.semibold, size: 11, relativeTo: .caption2)
  static let tab = Font.custom(Inter.medium, size: 13, relativeTo: .footnote)
  static let segment = Font.custom(Inter.medium, size: 14, relativeTo: .subheadline)
  static let field = Font.custom(Inter.regular, size: 16, relativeTo: .callout)
  static let chart = Font.system(.footnote, design: .monospaced)
  static let chartEditor = Font.system(.body, design: .monospaced)

  private enum Inter {
    static let regular = "InterVariable"
    static let medium = "InterVariable-Medium"
    static let semibold = "InterVariable-SemiBold"
  }

  private enum Serif {
    static let semibold = "SourceSerif4Variable-Semibold"
  }
}

/// The spacing scale. Every padding / inset / list gap traces to one of these,
/// the same way colours trace to `IntradaColor` — so screens can't drift on the
/// standard rhythm. Names mirror the web `p-card` tokens to keep one spacing
/// language across shells. Genuine one-offs (a fixed component height, a 2pt
/// baseline nudge) stay literal; don't tokenise those.
enum IntradaSpacing {
  static let controlGap: CGFloat = 8
  static let cardCompact: CGFloat = 12
  static let row: CGFloat = 16
  static let card: CGFloat = 16
  static let section: CGFloat = 24
}

/// Corner-radius tokens. `card` is the rounding every card / inset surface uses.
enum IntradaRadius {
  static let card: CGFloat = 12
  /// Interactive control buttons (rep Clean/Missed, etc.).
  static let control: CGFloat = 13
  /// Type badges / small tinted chips.
  static let badge: CGFloat = 8
  /// Medium section/hero cards (e.g. the Progress mastery card).
  static let panel: CGFloat = 16
  /// The Practice one-tap hero — the single largest card in the app.
  static let hero: CGFloat = 22
  /// Fully-rounded pills (filter tabs, the rep/consistency chrome).
  static let pill: CGFloat = 999
}

/// Named motion tokens — the "engaging refresh" springs, the signature `fadeUp`
/// screen-entrance, and the one-shot reveal timings. The *modifiers* that consume
/// these (`.fadeUp`, `.pop`, the count-up/ring-draw) live in `Motion.swift`; this
/// is the token layer, the way `IntradaColor` is for colour. Every animation here
/// must collapse to a 150ms fade (or its final state) under Reduce Motion — the
/// modifiers enforce that.
enum IntradaMotion {
  // Named springs (response · dampingFraction), from the design system.
  static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
  static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.9)
  static let gentle = Animation.spring(response: 0.45, dampingFraction: 0.82)

  // `fadeUp` — the signature page-load reveal: opacity 0→1, translateY 12→0,
  // 500ms ease-out, staggered +60ms per item, once on first paint.
  static let fadeUpDuration: Double = 0.5
  static let fadeUpStagger: Double = 0.06
  static let fadeUpOffset: CGFloat = 12

  // One-shots.
  /// `barGrow` — scaleY 0→1 from the baseline; CSS `cubic-bezier(.2,.8,.3,1)`.
  static let barGrow = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.6)
  static let barGrowStagger: Double = 0.06
  /// MasteryDial count-up + ring-draw (ease-out cubic over 1.5s).
  static let countUpDuration: Double = 1.5
  /// `pop` — spring scale-in (0.55→1.09→1) for rep ticks/dots; low damping overshoots.
  static let pop = Animation.spring(response: 0.35, dampingFraction: 0.62)
  /// Reduce-Motion collapse target.
  static let reduceFade: Double = 0.15

  /// The per-item `fadeUp` animation for a given stagger index.
  static func fadeUp(index: Int) -> Animation {
    .easeOut(duration: fadeUpDuration).delay(Double(index) * fadeUpStagger)
  }
}

extension Color {
  /// Build a `Color` from a packed `0xRRGGBB` literal so tokens read like the
  /// Pencil hex values they mirror.
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}
