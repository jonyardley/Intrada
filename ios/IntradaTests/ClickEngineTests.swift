import Testing

@testable import Intrada

@MainActor
struct ClickEngineTests {
  private func pulse(bpm: Double, latencySeconds: Double = 0) throws -> ClickEngine.Pulse {
    let tempo = try #require(ClickEngine.Tempo(bpm: bpm))
    return ClickEngine.Pulse(
      tempo: tempo, scheduledStart: 0,
      outputLatencyTicks: HostClock.ticks(fromSeconds: latencySeconds))
  }

  /// A pattern gates which beats sound and never which beats exist: beat 4 of
  /// a 4/4 bar at 120 is still beat 4 of the same 120 grid.
  @Test func aPatternGatesBeatsByTheirPlaceInTheBar() {
    let beatFour = ClickEngine.BeatPattern(beats: 4, sounding: 0b1000)
    #expect(!beatFour.sounds(beat: 0))
    #expect(!beatFour.sounds(beat: 2))
    #expect(beatFour.sounds(beat: 3))
    #expect(beatFour.sounds(beat: 7), "the bar repeats across the rolling window")
    #expect(!beatFour.sounds(beat: 4000))

    let groupStarts = ClickEngine.BeatPattern(beats: 7, sounding: 0b0101001)
    #expect([0, 3, 5].allSatisfy { groupStarts.sounds(beat: $0) })
    #expect(![1, 2, 4, 6].contains { groupStarts.sounds(beat: $0) })
    #expect(ClickEngine.BeatPattern.flat.sounds(beat: 12345))
  }

  /// The indicator reads the audio's clock: the beat shown is the one being
  /// heard, offset by output latency, and it wraps at the bar.
  @Test func theCurrentBeatIsDerivedFromTheAudibleGrid() throws {
    let p = try pulse(bpm: 120, latencySeconds: 0.1)
    let audibleStart = p.scheduledStart &+ p.outputLatencyTicks
    let at = { (seconds: Double) in audibleStart &+ HostClock.ticks(fromSeconds: seconds) }

    #expect(ClickEngine.beatIndex(at: p.scheduledStart, pulse: p, beats: 4) == nil)
    #expect(ClickEngine.beatIndex(at: at(0.0), pulse: p, beats: 4) == 0)
    #expect(ClickEngine.beatIndex(at: at(0.49), pulse: p, beats: 4) == 0)
    #expect(ClickEngine.beatIndex(at: at(0.5), pulse: p, beats: 4) == 1)
    #expect(ClickEngine.beatIndex(at: at(1.75), pulse: p, beats: 4) == 3)
    #expect(ClickEngine.beatIndex(at: at(2.0), pulse: p, beats: 4) == 0, "wraps at the bar")
    #expect(ClickEngine.beatIndex(at: at(3.25), pulse: p, beats: 7) == 6)
  }

  @Test func everyBeatSitsOnTheGridStruckFromTheStart() throws {
    let beats = try ClickEngine.schedule(beats: 0..<9, pulse: pulse(bpm: 120))

    for (index, beat) in beats.enumerated() {
      let seconds = HostClock.seconds(fromTicks: beat.hostTime)
      #expect(abs(seconds - Double(index) * 0.5) < 0.000_001)
    }
  }

  /// The window is topped up thousands of beats into a session, so beat N is
  /// N × the period from the *start*, never one period past its predecessor —
  /// per-beat accumulation would round its way off the grid.
  @Test func aBeatThousandsInIsStillOnTheOriginalGrid() throws {
    let secondsPerBeat = 60.0 / 132.0
    let beats = try ClickEngine.schedule(beats: 5000..<5001, pulse: pulse(bpm: 132))

    let seconds = HostClock.seconds(fromTicks: beats[0].hostTime)
    #expect(abs(seconds - 5000 * secondsPerBeat) < 0.000_001)
  }

  @Test func aLaterWindowPicksUpExactlyOnePeriodAfterTheOneBefore() throws {
    let first = try ClickEngine.schedule(beats: 0..<64, pulse: pulse(bpm: 120))
    let second = try ClickEngine.schedule(beats: 64..<128, pulse: pulse(bpm: 120))

    let gap = HostClock.secondsBetween(second[0].hostTime, first[63].hostTime)
    #expect(abs(gap - 0.5) < 0.000_001)
  }

  @Test func aBeatIsHeardOneOutputLatencyAfterItIsScheduled() throws {
    let latency = HostClock.ticks(fromSeconds: 0.012)
    let beats = try ClickEngine.schedule(beats: 0..<4, pulse: pulse(bpm: 90, latencySeconds: 0.012))

    for beat in beats {
      #expect(beat.audibleHostTime == beat.hostTime &+ latency)
    }
  }

  // ── The stranded clock (#1223 review) ──

  @Test func aPulseSuspendedForFiveMinutesIsStranded() {
    let secondsPerBeat = 0.5
    let head = HostClock.ticks(fromSeconds: 100)
    let fiveMinutesLater = head &+ HostClock.ticks(fromSeconds: 300)

    #expect(
      ClickEngine.hasLostTheClock(
        head: head, now: fiveMinutesLater, secondsPerBeat: secondsPerBeat))
  }

  /// A coalesced wakeup a beat or so late is what the 10ms poll exists to absorb.
  @Test func aWakeupUpToOneBeatLateIsNotStranded() {
    let secondsPerBeat = 0.5
    let head = HostClock.ticks(fromSeconds: 100)

    let onTime = head
    let slightlyLate = head &+ HostClock.ticks(fromSeconds: 0.2)
    let oneBeatLate = head &+ HostClock.ticks(fromSeconds: 0.5)

    #expect(!ClickEngine.hasLostTheClock(head: head, now: onTime, secondsPerBeat: secondsPerBeat))
    #expect(
      !ClickEngine.hasLostTheClock(head: head, now: slightlyLate, secondsPerBeat: secondsPerBeat))
    #expect(
      !ClickEngine.hasLostTheClock(head: head, now: oneBeatLate, secondsPerBeat: secondsPerBeat))
  }

  /// The case an unsigned subtraction would get catastrophically wrong.
  @Test func aBeatStillAheadIsNeverStranded() {
    let now = HostClock.ticks(fromSeconds: 100)
    let head = now &+ HostClock.ticks(fromSeconds: 30)

    #expect(!ClickEngine.hasLostTheClock(head: head, now: now, secondsPerBeat: 0.5))
  }

  @Test func theStrandedThresholdScalesWithTempoNotWallClock() {
    let head = HostClock.ticks(fromSeconds: 100)
    let threeSecondsLate = head &+ HostClock.ticks(fromSeconds: 3)

    // 240bpm: two beats is half a second, so three seconds is long gone.
    #expect(
      ClickEngine.hasLostTheClock(head: head, now: threeSecondsLate, secondsPerBeat: 0.25))
    // 40bpm: two beats is three seconds, so the same lag is still in tolerance.
    #expect(
      !ClickEngine.hasLostTheClock(head: head, now: threeSecondsLate, secondsPerBeat: 1.5))
  }

  @Test func aTempoTheGridCannotUseIsRefused() {
    #expect(ClickEngine.Tempo(bpm: 0) == nil)
    #expect(ClickEngine.Tempo(bpm: -120) == nil)
    #expect(ClickEngine.Tempo(bpm: .nan) == nil)
    #expect(ClickEngine.Tempo(bpm: .infinity) == nil)
    #expect(ClickEngine.Tempo(bpm: .leastNonzeroMagnitude) == nil)
    #expect(ClickEngine.Tempo(bpm: 120)?.secondsPerBeat == 0.5)
    #expect(ClickEngine.Tempo(bpm: 40)?.secondsPerBeat == 1.5)
  }
}
