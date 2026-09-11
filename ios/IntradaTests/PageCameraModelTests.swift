import AVFoundation
import Testing
import UIKit

@testable import Intrada

/// The hardware paths a simulator cannot reach: denied access, a camera that
/// will not start, and a capture that fails. All three are what the user sees
/// when the camera does not work, and none of them is reachable in a snapshot.
@MainActor
private final class StubCamera: PageCameraDevice {
  var session: AVCaptureSession? { nil }
  private(set) var stopCount = 0

  private let access: PageCameraAccess
  private let startError: Error?
  private let captureError: Error?

  init(access: PageCameraAccess = .allowed, startError: Error? = nil, captureError: Error? = nil) {
    self.access = access
    self.startError = startError
    self.captureError = captureError
  }

  func authorise() async -> PageCameraAccess { access }

  func start() async throws {
    if let startError { throw startError }
  }

  func stop() { stopCount += 1 }

  func capture() async throws -> UIImage {
    if let captureError { throw captureError }
    // A plain `UIImage` has no `cgImage`, so `PageCrop` returns it as taken
    // and the transition can be tested without running Vision.
    return UIImage()
  }
}

private enum StubError: Error { case failed }

@MainActor
struct PageCameraModelTests {
  @Test func refusedAccessBlocksWithTheReason() async {
    let model = PageCameraModel(device: StubCamera(access: .denied))

    await model.begin()

    guard case .blocked(let access) = model.stage else {
      Issue.record("expected blocked, got \(model.stage)")
      return
    }
    #expect(access == .denied)
  }

  @Test func aCameraThatWillNotStartIsNotReportedAsMissing() async {
    let model = PageCameraModel(device: StubCamera(startError: StubError.failed))

    await model.begin()

    guard case .unstartable = model.stage else {
      Issue.record("expected unstartable, got \(model.stage)")
      return
    }
  }

  @Test func aFailedCaptureSaysSoAndStaysOnTheViewfinder() async {
    let model = PageCameraModel(device: StubCamera(captureError: StubError.failed))
    await model.begin()

    await model.takePhoto()

    #expect(model.failure == "Couldn't take the photo. Try again.")
    guard case .live = model.stage else {
      Issue.record("expected to stay live, got \(model.stage)")
      return
    }
  }

  @Test func aSuccessfulCaptureWaitsToBeApproved() async {
    let model = PageCameraModel(device: StubCamera())
    await model.begin()

    await model.takePhoto()

    #expect(model.failure == nil)
    guard case .captured = model.stage else {
      Issue.record("expected captured, got \(model.stage)")
      return
    }
  }

  @Test func aFoundPageIsOfferedFlattened() async {
    let flattened = UIImage()
    let model = PageCameraModel(device: StubCamera(), crop: { _ in .flattened(flattened) })
    await model.begin()

    await model.takePhoto()

    guard case .captured(let page, let pageFound) = model.stage else {
      Issue.record("expected captured, got \(model.stage)")
      return
    }
    #expect(page === flattened)
    #expect(pageFound)
  }

  @Test func aMissedPageIsStillOfferedAndSaysSo() async {
    let model = PageCameraModel(device: StubCamera(), crop: { .asTaken($0) })
    await model.begin()

    await model.takePhoto()

    guard case .captured(_, let pageFound) = model.stage else {
      Issue.record("expected captured, got \(model.stage)")
      return
    }
    #expect(!pageFound)
    #expect(model.keep() != nil)
  }

  @Test func keepingThePageHandsItBackAndReleasesTheCamera() async {
    let camera = StubCamera()
    let model = PageCameraModel(device: camera)
    await model.begin()
    await model.takePhoto()

    #expect(model.keep() != nil)
    #expect(camera.stopCount == 1)
  }

  @Test func retakingReturnsToTheViewfinder() async {
    let model = PageCameraModel(device: StubCamera())
    await model.begin()
    await model.takePhoto()

    model.retake()

    guard case .live = model.stage else {
      Issue.record("expected live, got \(model.stage)")
      return
    }
  }

  /// The shutter stays hit-testable through the dismissal animation, and
  /// `capturePhoto` on a stopped session raises an ObjC exception no `catch`
  /// in the model can intercept.
  @Test func theShutterDoesNothingOnceTheScreenIsLeaving() async {
    let model = PageCameraModel(device: StubCamera())
    await model.begin()
    model.cancel()

    await model.takePhoto()

    guard case .live = model.stage else {
      Issue.record("expected to stay live, got \(model.stage)")
      return
    }
  }

  /// Dismissing after keeping must not stop a session that is already stopped.
  @Test func leavingAfterKeepingDoesNotStopTwice() async {
    let camera = StubCamera()
    let model = PageCameraModel(device: camera)
    await model.begin()
    await model.takePhoto()

    _ = model.keep()
    model.stopIfRunning()

    #expect(camera.stopCount == 1)
  }

  /// Cancel then a stray tap on Use this photo, which stays hit-testable
  /// through the dismissal transition, must not store a photo after all.
  @Test func keepingAfterCancellingStoresNothing() async {
    let camera = StubCamera()
    let model = PageCameraModel(device: camera)
    await model.begin()
    await model.takePhoto()

    model.cancel()

    #expect(model.keep() == nil)
    #expect(camera.stopCount == 1)
  }
}
