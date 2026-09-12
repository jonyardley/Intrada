import SharedTypes
import SwiftUI

/// The live, while-playing surface (the player's Focus screen). Renders the
/// core's `ActiveSessionView`; every control sends a `SessionEvent` and the core
/// drives the transition (Done on the last item → Summary). Full-screen, no
/// chrome — "the app disappears during practice".
struct FocusPlayerScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.screenWakeLock) private var wakeLock

  // Snapshots inject a fixed instant so the timer is deterministic; production
  // passes nil and the timer ticks off the wall clock (mirrors PracticeScreen).
  private let referenceDate: Date?

  init(referenceDate: Date? = nil) { self.referenceDate = referenceDate }

  @State private var reflecting: ReflectionTarget?
  @State private var click = ClickController()
  @State private var configuringClick = false
  @State private var switchingVariation = false

  private var active: ActiveSessionView? { store.viewModel?.activeSession }

  var body: some View {
    ZStack {
      RadialGradient.playerPaper.ignoresSafeArea()
      if let active {
        content(active)
      }
    }
    .sheet(item: $reflecting) { target in
      ReflectionSheet(
        itemTitle: target.title, elapsedDisplay: target.elapsedDisplay,
        tempoTarget: target.tempoTargetBpm, startingTempoBpm: target.startingTempoBpm,
        tempoUnit: target.tempoUnit, plays: target.plays,
        onSave: { result in handleReflection(target, result) },
        onSkip: { handleSkipRating() }
      )
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $configuringClick) {
      ClickSheet(click: click, bpm: click.bpm)
    }
    .sheet(isPresented: $switchingVariation) {
      if let active {
        VariationPickerSheet(
          itemTitle: active.currentItemTitle,
          variations: currentVariations(active),
          currentVariationId: active.currentVariationId,
          onPick: { switchVariation(active, to: $0) })
      }
    }
    .task { click.reseed(target: active?.currentItemTempoBpm, metre: active?.currentItemMetre) }
    .onChange(of: active?.currentPosition) { _, _ in
      click.reseed(target: active?.currentItemTempoBpm, metre: active?.currentItemMetre)
    }
    // `initial: true` is what takes the hold for a session started in the
    // foreground, where the phase never changes (#1513).
    // No `UIBackgroundModes: audio`, so the pulse cannot survive backgrounding
    // — stop it rather than leave the row claiming a click nobody can hear.
    .onChange(of: scenePhase, initial: true) { _, phase in
      wakeLock.update(sessionActive: active != nil, phase: phase)
      if phase == .background { click.stop() }
    }
    .onDisappear {
      click.dispose()
      wakeLock.release()
    }
  }

  private func content(_ active: ActiveSessionView) -> some View {
    VStack(spacing: 0) {
      topChrome(active).fadeUp(0)
      Spacer(minLength: IntradaSpacing.card)
      centerInfo(active).fadeUp(1)
      timer(active).fadeUp(2).padding(.top, IntradaSpacing.section)
      clickRow(active).padding(.top, IntradaSpacing.controlGap)
      if click.isRunning {
        barLine.padding(.top, IntradaSpacing.controlGap)
      }
      repCounter(active).fadeUp(3).padding(.top, IntradaSpacing.section)
      Spacer(minLength: IntradaSpacing.card)
      controls(active).fadeUp(4)
    }
    .padding(.horizontal, IntradaSpacing.card)
    .padding(.top, IntradaSpacing.card)
  }

  // ── Top: session elapsed + position label + progress + options menu ──

  @ViewBuilder private func topChrome(_ active: ActiveSessionView) -> some View {
    let start = SessionClock.parseRFC3339(active.startedAt)
    if let start, referenceDate == nil {
      // Anchored to the session start, not `.now`: `.now` re-phases the tick on
      // every body evaluation, so the two timers drift out of step on a screen
      // whose brief is to sit still.
      TimelineView(.periodic(from: start, by: 1)) { context in
        band(active, elapsed: Int(context.date.timeIntervalSince(start)))
      }
    } else {
      // A session total nobody can vouch for is worse than none: an unparsable
      // anchor would otherwise count up from screen appearance and read as fact.
      band(active, elapsed: start.map { Int((referenceDate ?? .now).timeIntervalSince($0)) })
    }
  }

  private func band(_ active: ActiveSessionView, elapsed: Int?) -> some View {
    SessionOrientationBand(
      sessionElapsed: elapsed,
      positionLabel: positionLabel(active),
      types: active.entries.map(\.itemType),
      filled: min(Int(active.currentPosition) + 1, Int(active.totalItems)),
      menu: { optionsMenu })
  }

  private func positionLabel(_ active: ActiveSessionView) -> String {
    "FOCUS · \(active.currentPosition + 1) OF \(active.totalItems)"
  }

  private var optionsMenu: some View {
    Menu {
      Button {
        store.send(.session(.skipItem(now: SessionClock.nowRFC3339())))
      } label: {
        Label("Skip this item", systemImage: "forward.end")
      }
      Button(role: .destructive) {
        store.send(.session(.endSessionEarly(now: SessionClock.nowRFC3339())))
      } label: {
        Label("End session early", systemImage: "stop.circle")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 20))
        .foregroundStyle(IntradaColor.inkSecondary)
        .frame(width: 28, height: 28)
    }
    .accessibilityLabel("Session options")
  }

  // ── Centre: intention echo, item identity, the live timer ──

  private func centerInfo(_ active: ActiveSessionView) -> some View {
    VStack(spacing: 28) {
      if let intention = active.sessionIntention, !intention.isEmpty {
        Text("“\(intention)”")
          .font(IntradaFont.body).italic()
          .foregroundStyle(IntradaColor.inkSecondary)
          .multilineTextAlignment(.center)
      }
      VStack(spacing: 8) {
        TypeBadge(kind: active.currentItemType)
        Text(active.currentItemTitle)
          .font(IntradaFont.pageTitle(34))
          .foregroundStyle(IntradaColor.ink)
          .multilineTextAlignment(.center)
        if let pieceTitle = active.currentRelatedPieceTitle {
          Label("Related to \(pieceTitle)", systemImage: "arrow.turn.down.right")
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.accent)
        }
        if let aim = active.currentItemIntention, !aim.isEmpty {
          Text("Aim: \(aim)")
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.inkSecondary)
            .multilineTextAlignment(.center)
        }
        variationChip(active)
      }
    }
    .padding(.horizontal, IntradaSpacing.card)
  }

  // ── The variation being practised right now (#1739 decision 6) ──

  @ViewBuilder private func variationChip(_ active: ActiveSessionView) -> some View {
    if !currentVariations(active).isEmpty {
      Button {
        switchingVariation = true
      } label: {
        HStack(spacing: 7) {
          Text(active.currentVariationLabel ?? "Pick a variation")
            .font(IntradaFont.segment)
            .foregroundStyle(
              active.currentVariationLabel == nil
                ? IntradaColor.inkSecondary : IntradaColor.ink
            )
            // A variation named "2nd inversion" shrinks rather than
            // ellipsising, as the click's readout does (T19).
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Image(systemName: "chevron.down")
            .font(IntradaFont.micro.weight(.semibold))
            .foregroundStyle(IntradaColor.inkSecondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(IntradaColor.cardFill, in: Capsule())
        .overlay(Capsule().stroke(IntradaColor.hairline, lineWidth: 1))
        .cardShadow()
      }
      .buttonStyle(PressRebound())
      .accessibilityLabel("Variation")
      .accessibilityValue(active.currentVariationLabel ?? "none picked")
      .accessibilityHint("Switches to another variation of this exercise")
    }
  }

  /// The current item's live variations, read unfiltered so the Library's own
  /// search cannot empty the picker (#1484).
  private func currentVariations(_ active: ActiveSessionView) -> [VariantView] {
    let pos = Int(active.currentPosition)
    guard active.entries.indices.contains(pos) else { return [] }
    let itemId = active.entries[pos].itemId
    return store.viewModel?.allItems.first(where: { $0.id == itemId })?.variants ?? []
  }

  /// False when the core refused the switch (the per-entry cap, or a variation
  /// that has since been deleted), so the picker stays up beside the banner.
  private func switchVariation(_ active: ActiveSessionView, to variationId: String) -> Bool {
    let pos = Int(active.currentPosition)
    guard active.entries.indices.contains(pos) else { return false }
    let before = store.viewModel?.errorSeq
    store.send(
      .session(
        .switchVariation(
          entryId: active.entries[pos].id, variationId: variationId,
          now: SessionClock.nowRFC3339())))
    return store.viewModel?.errorSeq == before
  }

  @ViewBuilder private func timer(_ active: ActiveSessionView) -> some View {
    let start = SessionClock.parseRFC3339(active.currentItemStartedAt) ?? Date()
    if let referenceDate {
      timerBody(
        elapsed: Int(referenceDate.timeIntervalSince(start)),
        planned: active.currentPlannedDurationSecs)
    } else {
      TimelineView(.periodic(from: start, by: 1)) { context in
        timerBody(
          elapsed: Int(context.date.timeIntervalSince(start)),
          planned: active.currentPlannedDurationSecs)
      }
    }
  }

  @ViewBuilder private func timerBody(elapsed: Int, planned: UInt32?) -> some View {
    TimerRing(elapsed: elapsed, planned: planned.map(Int.init))
  }

  // A marking with no BPM ("Andante", no number) is not a tempo the click can
  // play, so the row falls through to naming the click rather than advertising
  // a target the next tap would not sound.
  private func clickRow(_ active: ActiveSessionView) -> some View {
    let declared = active.currentItemTempoBpm != nil
    return ClickControl(
      bpm: click.bpm, unit: click.metre.unit, isRunning: click.isRunning,
      unavailable: click.unavailable,
      atSeededTempo: click.isAtSeededTempo,
      targetDisplay: declared ? active.currentItemTempoDisplay : nil,
      targetSpoken: declared ? active.currentItemTempoSpoken : nil,
      onToggle: { click.toggle() },
      onStep: { click.step(by: $0) })
  }

  // The indicator reads the audio's clock through the engine on every frame,
  // so it cannot drift against the click the way a view timer would (T19).
  // Snapshots pass a reference date and get a settled frame with no ring.
  @ViewBuilder private var barLine: some View {
    if referenceDate != nil {
      barLineBody(currentBeat: nil)
    } else {
      TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
        barLineBody(currentBeat: click.currentBeat())
      }
    }
  }

  private func barLineBody(currentBeat: Int?) -> some View {
    ClickBarLine(
      metre: click.metre, sounding: click.sounding, currentBeat: currentBeat,
      onTap: { configuringClick = true })
  }

  // ── Repetitions (resident; the core records nothing until the first tap) ──

  private func repCounter(_ active: ActiveSessionView) -> some View {
    RepCounter(
      count: Int(active.currentRepCount ?? 0),
      slots: Int(active.currentRepSlots),
      touched: active.currentRepCount != nil,
      reached: active.currentRepTargetReached ?? false,
      onGotIt: { store.send(.session(.repGotIt(now: SessionClock.nowRFC3339()))) },
      onNotQuite: { store.send(.session(.repMissed(now: SessionClock.nowRFC3339()))) })
  }

  // ── Bottom: transport (advance + skip-forward) + next-item hint ──

  private func controls(_ active: ActiveSessionView) -> some View {
    VStack(spacing: 14) {
      HStack(spacing: 32) {
        Button {
          presentReflection(active)
        } label: {
          Image(systemName: "play.fill")
            .font(.system(size: 32))
            .foregroundStyle(IntradaColor.onAccent)
            .frame(width: 78, height: 78)
            .background(LinearGradient.inkBar)
            .clipShape(Circle())
            .shadow(color: IntradaColor.ink.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(PressRebound())
        .accessibilityLabel(active.nextItemTitle == nil ? "Finish session" : "Next item")

        Button {
          store.send(.session(.skipItem(now: SessionClock.nowRFC3339())))
        } label: {
          Image(systemName: "forward.end")
            .font(.system(size: 22))
            .foregroundStyle(IntradaColor.inkSecondary)
            .frame(width: 48, height: 48)
        }
        .buttonStyle(PressRebound())
        .accessibilityLabel("Skip this item")
      }
      if let next = active.nextItemTitle {
        Text("Next · \(next)")
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
      }
    }
    .padding(.bottom, IntradaSpacing.card)
  }

  // ── Reflection at hand-off ───────────────────────────────────────────

  private struct ReflectionTarget: Identifiable {
    let id: String  // the current entry's ulid
    let title: String
    let elapsedDisplay: String
    let tempoTargetBpm: UInt16?
    let startingTempoBpm: Int
    /// The click was sounding when the item ended, so `startingTempoBpm`
    /// measures what they played to rather than being an untouched default.
    let clickSounding: Bool
    /// The bar and pattern the click was set to, or `nil` when the click was
    /// never touched for this item: the core rules on whether the tempo is in
    /// quavers and whether the pattern was evidenced (#1499).
    let clickState: ClickState?
    /// The unit the stepper counts in, which is the click's when the player
    /// chose one and crotchets when they did not.
    var tempoUnit: UInt8 { clickState?.metre.unit ?? 4 }
    /// What was played, oldest first, one row per variation (#1739). The last
    /// is the play still open at the moment the item ended, which `NextItem`
    /// then closes.
    let plays: [ReflectionPlay]
  }

  private func presentReflection(_ active: ActiveSessionView) {
    let pos = Int(active.currentPosition)
    guard active.entries.indices.contains(pos) else {
      store.send(.session(.nextItem(now: SessionClock.nowRFC3339())))
      return
    }
    let start = SessionClock.parseRFC3339(active.currentItemStartedAt) ?? Date()
    let elapsed = max(Int((referenceDate ?? Date()).timeIntervalSince(start)), 0)
    // Both read before stop() below.
    let startingTempoBpm = click.bpm
    let clickSounding = click.isRunning
    let clickState = click.clickState
    // The item is over; a click ticking through the rating is keeping time for
    // nothing.
    click.stop()
    let entry = active.entries[pos]
    reflecting = ReflectionTarget(
      id: entry.id, title: active.currentItemTitle,
      elapsedDisplay: SessionClock.clockDisplay(elapsed),
      tempoTargetBpm: active.currentItemTempoBpm, startingTempoBpm: startingTempoBpm,
      clickSounding: clickSounding, clickState: clickState,
      plays: ReflectionPlay.rows(entry.plays, elapsed: elapsed))
  }

  // Notes first (no status guard — surfaces a validation error before advancing);
  // then NextItem completes the entry so the score and tempo can land (both
  // need Completed). Errors surface on RootView's banner, so dismiss only on
  // success.
  private func handleReflection(_ target: ReflectionTarget, _ result: ReflectionResult) {
    if !result.note.isEmpty {
      let before = store.viewModel?.errorSeq
      store.send(.session(.updateEntryNotes(entryId: target.id, notes: result.note)))
      if store.viewModel?.errorSeq != before { return }
    }
    store.send(.session(.nextItem(now: SessionClock.nowRFC3339())))
    // NextItem is the terminal transition that drops a stretch nobody
    // practised, so a mark is only sent for a play the core still holds:
    // marking a row and then watching an error banner say that row is gone
    // is worse than losing a mark on a stray tap of the picker (#1739).
    let surviving = survivingPlayIds(target.id)
    for play in target.plays {
      guard let score = result.marks[play.id], surviving?.contains(play.id) ?? true else {
        continue
      }
      store.send(.session(.updateEntryScore(entryId: target.id, playId: play.id, score: score)))
    }
    // The two facts go over as observed and the core rules on whether they
    // amount to evidence (#1420); deciding here would be domain logic in the
    // shell. It lands on the last stretch the core kept, not simply the last:
    // a switch seconds before the item ended leaves a play the core discards,
    // and skipping the write there would lose a reading the click evidenced
    // over the whole item. Which variation a mid-item tempo change belongs to
    // is #1761.
    let tempoPlayId = target.plays.last(where: { surviving?.contains($0.id) ?? true })?.id
    if let openPlayId = tempoPlayId {
      store.send(
        .session(
          .updateEntryTempo(
            entryId: target.id, playId: openPlayId, tempo: result.achievedTempo,
            observed: TempoObservation(
              userSet: result.tempoUserSet, clickSounding: target.clickSounding),
            click: target.clickState)))
    }
    reflecting = nil
  }

  /// The entry after `NextItem` closed it: still in the setlist mid-session,
  /// and in the summary once that was the last item. `nil` when the shell
  /// cannot find it, which sends every mark rather than swallowing them all.
  private func survivingPlayIds(_ entryId: String) -> Swift.Set<String>? {
    let model = store.viewModel
    let entries = (model?.activeSession?.entries ?? []) + (model?.summary?.entries ?? [])
    guard let entry = entries.first(where: { $0.id == entryId }) else { return nil }
    return Swift.Set(entry.plays.map(\.id))
  }

  private func handleSkipRating() {
    store.send(.session(.nextItem(now: SessionClock.nowRFC3339())))
    reflecting = nil
  }
}

/// Calm circular timer ring — elapsed time centred, planned arc swept clockwise.
/// Static (no pulse/glow): the player surface should sit still while practice runs.
private struct TimerRing: View {
  let elapsed: Int
  let planned: Int?

  private var fraction: Double {
    guard let planned, planned > 0 else { return 0 }
    return min(Double(elapsed) / Double(planned), 1)
  }

  var body: some View {
    ZStack {
      // The 200 box is the price of the resident counter (T19); the ring had
      // the most slack. The time stays centred at full size.
      ZStack {
        Circle().stroke(IntradaColor.timerTrack, lineWidth: 10)
        if planned != nil {
          Circle()
            .trim(from: 0, to: fraction)
            .stroke(
              LinearGradient.ringSweep,
              style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
        }
      }
      .padding(18)
      VStack(spacing: 4) {
        Text(SessionClock.clockDisplay(elapsed))
          .font(IntradaFont.timer(48))
          .monospacedDigit()
          .foregroundStyle(IntradaColor.ink)
        if let planned {
          Text("of \(SessionClock.clockDisplay(planned))")
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.inkSecondary)
        }
      }
    }
    .frame(width: 200, height: 200)
    .accessibilityElement(children: .ignore)
    // Named for the item rather than just "Elapsed": the orientation band now
    // carries a session timer too, so an unqualified label reads as either (T19).
    .accessibilityLabel("This item")
    .accessibilityValue(
      planned == nil
        ? SessionClock.clockDisplay(elapsed)
        : "\(SessionClock.clockDisplay(elapsed)) of \(SessionClock.clockDisplay(planned ?? 0))"
    )
  }
}

#if DEBUG
  #Preview("Untouched") {
    FocusPlayerScreen().environment(Store.previewActive)
  }

  #Preview("Reps") {
    FocusPlayerScreen().environment(Store.previewActiveReps)
  }

  #Preview("Variations") {
    FocusPlayerScreen().environment(Store.previewActiveVariations)
  }
#endif
