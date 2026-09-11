import AVFoundation
import SwiftUI

/// Whether the camera can be used at all, once the system has been asked.
enum PageCameraAccess {
  case allowed
  case denied
  case unavailable
}

enum PageCameraError: Error {
  case noCamera
  case unreadablePhoto
}

/// What `PageCameraScreen` needs from the hardware. Behind a protocol because
/// there is no camera on a simulator and every gate we own runs on one: the
/// permission, failure and confirm states are otherwise untestable (#1460).
@MainActor
protocol PageCameraDevice: AnyObject {
  /// `nil` until the session is configured, so the preview never attaches to
  /// an empty one.
  var session: AVCaptureSession? { get }
  func authorise() async -> PageCameraAccess
  func start() async throws
  func stop()
  func capture() async throws -> UIImage
  /// The preview layer, once `CameraPreview` has one; `onRotate` reports the
  /// applied angle so the caller can shape the preview's box to match (#1548).
  func attachPreviewLayer(
    _ layer: AVCaptureVideoPreviewLayer, onRotate: @escaping (CGFloat) -> Void)
}

@MainActor
final class AVPageCameraDevice: PageCameraDevice {
  static var isAvailable: Bool {
    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
  }

  private lazy var hardware = CaptureSessionBox()
  private var configured = false
  /// `AVCapturePhotoOutput` does not retain its delegate, so the capture in
  /// flight is held here or it deallocates before the photo arrives.
  private var inFlight: PhotoCaptureDelegate?
  private var camera: AVCaptureDevice?
  private weak var previewLayer: AVCaptureVideoPreviewLayer?
  /// Tracks physical attitude via the gyroscope: the phone build is
  /// portrait-only, so interface orientation can't drive this (#1548).
  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
  private var rotationObservation: NSKeyValueObservation?
  private var onRotate: ((CGFloat) -> Void)?

  var session: AVCaptureSession? { configured ? hardware.session : nil }

  func attachPreviewLayer(
    _ layer: AVCaptureVideoPreviewLayer, onRotate: @escaping (CGFloat) -> Void
  ) {
    previewLayer = layer
    self.onRotate = onRotate
    if let camera {
      makeRotationCoordinator(for: camera, previewLayer: layer)
    }
  }

  func authorise() async -> PageCameraAccess {
    guard Self.isAvailable else { return .unavailable }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return .allowed
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
    default:
      return .denied
    }
  }

  func start() async throws {
    try configure()
    await hardware.startRunning()
  }

  func stop() {
    guard configured else { return }
    // The coordinator polls the gyroscope; nothing else stops it (#1548).
    rotationObservation = nil
    rotationCoordinator = nil
    previewLayer = nil
    onRotate = nil
    hardware.stopRunning()
  }

  func capture() async throws -> UIImage {
    defer { inFlight = nil }
    if let connection = hardware.output.connection(with: .video),
      let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
      connection.isVideoRotationAngleSupported(angle)
    {
      connection.videoRotationAngle = angle
    }
    return try await withCheckedThrowingContinuation { continuation in
      let delegate = PhotoCaptureDelegate { continuation.resume(with: $0) }
      inFlight = delegate
      hardware.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
  }

  private func configure() throws {
    guard !configured else { return }
    guard
      let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: camera)
    else {
      throw PageCameraError.noCamera
    }

    let session = hardware.session
    session.beginConfiguration()
    session.sessionPreset = .photo
    guard session.canAddInput(input), session.canAddOutput(hardware.output) else {
      session.commitConfiguration()
      throw PageCameraError.noCamera
    }
    session.addInput(input)
    session.addOutput(hardware.output)
    session.commitConfiguration()
    self.camera = camera
    configured = true
  }

  private func makeRotationCoordinator(
    for camera: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer
  ) {
    let coordinator = AVCaptureDevice.RotationCoordinator(
      device: camera, previewLayer: previewLayer)
    rotationCoordinator = coordinator
    applyPreviewAngle(coordinator.videoRotationAngleForHorizonLevelPreview)

    rotationObservation = coordinator.observe(
      \.videoRotationAngleForHorizonLevelPreview, options: [.new]
    ) { [weak self] _, change in
      guard let angle = change.newValue else { return }
      Task { @MainActor in self?.applyPreviewAngle(angle) }
    }
  }

  private func applyPreviewAngle(_ angle: CGFloat) {
    guard let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle)
    else { return }
    connection.videoRotationAngle = angle
    // Deferred: the first call lands inside `CameraPreview.makeUIView`, a
    // SwiftUI view update, and `onRotate` writes `@State` (#1548).
    let onRotate = onRotate
    Task { @MainActor in onRotate?(angle) }
  }
}

/// AVFoundation predates `Sendable`, and `startRunning` blocks for long enough
/// to land the sheet frozen if it runs on the main actor. The session lives
/// here so the blocking calls happen on a private queue without the session
/// itself ever crossing an isolation boundary.
private final class CaptureSessionBox: @unchecked Sendable {
  let session = AVCaptureSession()
  let output = AVCapturePhotoOutput()
  private let queue = DispatchQueue(label: "com.intrada.page-camera")

  func startRunning() async {
    await withCheckedContinuation { continuation in
      queue.async {
        if !self.session.isRunning {
          self.session.startRunning()
        }
        continuation.resume()
      }
    }
  }

  func stopRunning() {
    queue.async {
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let finished: (Result<UIImage, Error>) -> Void

  init(finished: @escaping (Result<UIImage, Error>) -> Void) {
    self.finished = finished
  }

  func photoOutput(
    _: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error {
      finished(.failure(error))
      return
    }
    guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
      finished(.failure(PageCameraError.unreadablePhoto))
      return
    }
    finished(.success(image))
  }
}
