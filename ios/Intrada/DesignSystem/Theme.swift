import SharedTypes
import SwiftUI

/// Every colour, gradient, and type style the native shell draws traces back to
/// a token here — views never hard-code a hex value or raw `.system` font.
enum IntradaColor {
  static let paperTop = Color(hex: 0xF7F4EF)

  static let cardFill = Color(hex: 0xFFFFFF)
  static let surfaceSunken = Color(hex: 0xF3EFE8)
  static let hairline = Color(hex: 0xECE6DA)
  static let divider = Color(hex: 0xDDD7CA)

  static let ink = Color(hex: 0x3B2A1E)
  static let inkSecondary = Color(hex: 0x7A6A5A)
  /// Eyebrow labels only: fails WCAG AA (2.45:1 on paper); metadata/body use inkSecondary.
  static let inkFaint = Color(hex: 0xA99C8C)
  /// A dimmed glyph with no text of its own to fall back on (#1458): 3.49:1 on
  /// paper, clearing the 3:1 floor for non-text graphical objects
  /// (WCAG 1.4.11). Never for text; `inkFaint` already fails that.
  static let inkFaintIcon = Color(hex: 0x8F8070)

  /// No brand hue: the interactive colour on paper is ink (#1676).
  static let accent = ink
  static let onAccent = Color(hex: 0xFFFFFF)
  /// The one bright colour. Butter is the default; views read the chosen one
  /// from `@Environment(\.marker)` (#1677), never this token directly.
  static let marker = Color(hex: 0xFFE9A3)
  /// The eight marker pastels, in the order of the token sheet.
  static func marker(_ colour: HighlighterColour) -> Color {
    switch colour {
    case .butter: marker
    case .coral: Color(hex: 0xFFB4A2)
    case .mint: Color(hex: 0xB9EBD3)
    case .sky: Color(hex: 0xA9D8FF)
    case .lavender: Color(hex: 0xD6CCF5)
    case .sage: Color(hex: 0xCFDDB0)
    case .peach: Color(hex: 0xFFD7B0)
    case .powder: Color(hex: 0xC7DCE8)
    }
  }
  static let onMarker = ink
  static let danger = Color(hex: 0x9C4A3A)
  /// The banner and whatever it points at wear the same wash, so the pair reads
  /// as one thing rather than two unrelated red surfaces (#1595).
  static let dangerWash = danger.opacity(0.10)
  static let dangerEdge = danger.opacity(0.25)
  static let shadow = ink.opacity(0.05)
  static let buttonShadow = ink.opacity(0.06)

  static let tabBarFill = Color(hex: 0xF3EFE8)

  /// Duller than `marker` so a badge never reads as a button (T3).
  static let pieceBadgeBg = Color(hex: 0xCBD6E0)
  static let pieceBadgeFg = ink
  static let exerciseBadgeBg = Color(hex: 0xDCD3C0)
  static let exerciseBadgeFg = ink

  // ── Engaging-refresh tokens ──
  /// Mastery gains, clean reps, trending-up. Reserved from `danger` (destructive).
  static let success = Color(hex: 0x4C6B3F)
  /// Mastery is monochrome ink: the *count* carries meaning (colour-blind
  /// safe); never recolour a meter/dial by level.
  static let masteryFill = ink
  static let masteryTrack = Color(hex: 0xEDE8DC)
  static let dialTrack = Color(hex: 0xEDE8DC)
  static let timerTrack = Color(hex: 0xEDE8DC)
  static let consistencyTrack = Color(hex: 0xEDE8DC)
  /// A "missed" rep is taupe, never red — calm, not shaming.
  static let repMissedFg = Color(hex: 0x756A5C)
  static let repMissedBg = Color(hex: 0xF3EFE8)
  static let repCleanFg = success
  static let repCleanBg = Color(hex: 0xEDF1EA)
  static let repCleanBorder = Color(hex: 0xD3DDCC)
  /// Empty rep-slot ring + missed-button border.
  static let slotOutline = Color(hex: 0xDDD7CA)
  /// Dashed outline on full-width "+ Add …" rows.
  static let addDashOutline = Color(hex: 0xC9BFB0)
  /// The faded "was" number in a was→now delta.
  static let figureMuted = Color(hex: 0xC2B8AA)
  /// Not-yet days in the week picker.
  static let futureDay = Color(hex: 0xC9BFB0)
  static let inkFainter = Color(hex: 0xC2B8AA)
  // Focus-player warm radial backdrop.
  static let playerBgTop = Color(hex: 0xFBFAF7)
  static let playerBgMid = Color(hex: 0xF7F4EF)
  static let playerBgBottom = Color(hex: 0xEFEAE1)
  static let heroGradientTop = ink
  static let heroGradientBottom = Color(hex: 0x56412C)
  /// Read `ItemKind.onHeroAccent`, not these directly.
  static let onHeroExercise = exerciseBadgeBg
  static let onHeroPiece = pieceBadgeBg
  static let celebrationBg = ink
  static let celebrationInk = paperTop
  /// The full-screen photo viewer's ground. Warm near-black from the ink family
  /// rather than paper: cream around a photograph tints how you read the page.
  static let viewerBackdrop = Color(hex: 0x1A1917)
}

extension LinearGradient {
  static let paper = LinearGradient(
    colors: [IntradaColor.paperTop], startPoint: .top, endPoint: .bottom)

  static let inkBar = LinearGradient(
    colors: [IntradaColor.ink], startPoint: .top, endPoint: .bottom)

  static let celebration = LinearGradient(
    colors: [IntradaColor.celebrationBg], startPoint: .top, endPoint: .bottom)

  static let pieceBar = LinearGradient(
    colors: [IntradaColor.pieceBadgeBg], startPoint: .top, endPoint: .bottom)

  static let exerciseBar = LinearGradient(
    colors: [IntradaColor.exerciseBadgeBg], startPoint: .top, endPoint: .bottom)

  /// The Practice one-tap hero card (CSS `165deg` ≈ top-trailing → bottom-leading).
  static let practiceHero = LinearGradient(
    colors: [IntradaColor.heroGradientTop, IntradaColor.heroGradientBottom],
    startPoint: .topTrailing, endPoint: .bottomLeading)

  static let ringSweep = LinearGradient(
    colors: [IntradaColor.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension RadialGradient {
  /// The Focus-player warm cream wash — CSS `radial-gradient(120% 80% at 50% 22%)`.
  static let playerPaper = RadialGradient(
    colors: [
      IntradaColor.playerBgTop, IntradaColor.playerBgMid, IntradaColor.playerBgBottom,
    ],
    center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 440)
}

/// Semantic type styles: Hanken Grotesk, with DM Mono for metadata (bundled via
/// `IntradaFonts`). `relativeTo:` tracks Dynamic Type; weights use named-instance
/// PostScript names, not `.weight()`, which is synthetic over a variable axis.
enum IntradaFont {
  static func pageTitle(_ size: CGFloat = 29) -> Font {
    .custom(Hanken.semibold, size: size, relativeTo: .largeTitle)
  }
  static func cardTitle(_ size: CGFloat = 16) -> Font {
    .custom(Hanken.semibold, size: size, relativeTo: .title3)
  }
  /// The live session timer at display size. Pair with `.monospacedDigit()`.
  static func timer(_ size: CGFloat = 56) -> Font {
    .custom(Hanken.semibold, size: size, relativeTo: .largeTitle)
  }
  static func scoreNumeral(_ size: CGFloat) -> Font {
    .custom(Hanken.semibold, size: size, relativeTo: .title3)
  }

  static let body = Font.custom(Hanken.regular, size: 14, relativeTo: .subheadline)
  static let bodyMedium = Font.custom(Hanken.medium, size: 15, relativeTo: .subheadline)
  static let button = Font.custom(Hanken.bold, size: 13.5, relativeTo: .subheadline)
  static let subtitle = Font.custom(Mono.regular, size: 12.5, relativeTo: .footnote)
  static let meta = Font.custom(Mono.regular, size: 12.5, relativeTo: .caption)
  static let micro = Font.custom(Hanken.regular, size: 10, relativeTo: .caption2)
  static let metaMedium = Font.custom(Hanken.medium, size: 12, relativeTo: .caption)
  static let badge = Font.custom(Hanken.semibold, size: 12, relativeTo: .caption)
  /// Uppercase section label (letter-spaced, `inkFaint`) — the eyebrow above
  /// every section on the refreshed screens.
  static let eyebrow = Font.custom(Hanken.semibold, size: 11, relativeTo: .caption2)
  static let tab = Font.custom(Hanken.medium, size: 13, relativeTo: .footnote)
  static let segment = Font.custom(Hanken.medium, size: 14, relativeTo: .subheadline)
  static let field = Font.custom(Hanken.regular, size: 16, relativeTo: .callout)
  static let chart = Font.system(.footnote, design: .monospaced)
  static let chartEditor = Font.system(.body, design: .monospaced)

  enum Hanken {
    static let regular = "HankenGrotesk-Regular"
    static let medium = "HankenGrotesk-Medium"
    static let semibold = "HankenGrotesk-SemiBold"
    static let bold = "HankenGrotesk-Bold"
  }

  enum Mono {
    static let regular = "DMMono-Regular"
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
  static let card: CGFloat = 3
  /// Interactive control buttons (rep Clean/Missed, etc.).
  static let control: CGFloat = 3
  /// Type badges / small tinted chips.
  static let badge: CGFloat = 3
  /// Medium section/hero cards (e.g. the Progress mastery card).
  static let panel: CGFloat = 3
  /// The Practice one-tap hero — the single largest card in the app.
  static let hero: CGFloat = 3
  /// Fully-rounded pills (filter tabs, the rep/consistency chrome).
  static let pill: CGFloat = 999
}

/// Instrument icon sizes from the profile mock (#1690): the header button, a
/// picker tile, the profile hero.
enum IntradaGlyph {
  static let bar: CGFloat = 36
  static let tile: CGFloat = 56
  static let hero: CGFloat = 88
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
