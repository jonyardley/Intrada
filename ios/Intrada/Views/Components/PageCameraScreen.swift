import AVFoundation
import SwiftUI

/// Where the camera has got to. Lives outside the view so the transitions the
/// hardware drives can be tested with a stub device: none of them are reachable
/// on a simulator (#1460).
@MainActor
@Observable
final class PageCameraModel {
  enum Stage {
    case preparing
    case live
    /// The cropped page, not the raw frame: what you approve is what is stored.
    /// Without a page found it is the photo as taken, and the confirm says so.
    case captured(UIImage, pageFound: Bool)
    case blocked(PageCameraAccess)
    /// The camera exists but would not start, usually because something else
    /// holds it. Distinct from `blocked`, whose copy says there is no camera.
    case unstartable
  }

  private(set) var stage: Stage = .preparing
  private(set) var failure: String?
  private(set) var capturing = false
  /// Set once the screen is on its way out. The shutter stays hit-testable
  /// through the dismissal transition, and `capturePhoto` on a stopped session
  /// raises an ObjC exception no `catch` here can intercept.
  private(set) var finished = false

  private let device: any PageCameraDevice
  private let crop: @Sendable (UIImage) -> PageCrop.Outcome

  init(
    device: any PageCameraDevice,
    crop: @escaping @Sendable (UIImage) -> PageCrop.Outcome = PageCrop.toPage
  ) {
    self.device = device
    self.crop = crop
  }

  var session: AVCaptureSession? { device.session }

  func attachPreviewLayer(
    _ layer: AVCaptureVideoPreviewLayer, onRotate: @escaping (CGFloat) -> Void
  ) {
    device.attachPreviewLayer(layer, onRotate: onRotate)
  }

  /// The sensor delivers 4:3 landscape; 0° and 180° are the sideways angles
  /// against the shipped portrait case of 90° (#1548).
  static func isLandscape(angle: CGFloat) -> Bool {
    angle == 0 || angle == 180
  }

  func begin() async {
    let access = await device.authorise()
    guard access == .allowed else {
      stage = .blocked(access)
      return
    }
    do {
      try await device.start()
      // The cover can be torn down while the permission dialog is up, and the
      // session would otherwise start onto a dismissed screen and run on.
      guard !finished else {
        device.stop()
        return
      }
      stage = .live
    } catch {
      report(error, "page camera start")
      stage = .unstartable
    }
  }

  func takePhoto() async {
    guard !capturing, !finished else { return }
    capturing = true
    failure = nil
    defer { capturing = false }

    do {
      let shot = try await device.capture()
      // The system scanner cropped its own output; ours has to, and the work
      // blocks long enough to drop frames.
      let crop = crop
      let page = await Task.detached(priority: .userInitiated) { crop(shot) }.value
      stage = .captured(page.image, pageFound: page.pageFound)
    } catch {
      report(error, "page camera capture")
      failure = "Couldn't take the photo. Try again."
    }
  }

  func retake() {
    stage = .live
  }

  /// The page to keep, or `nil` if there is nothing captured to keep.
  func keep() -> UIImage? {
    guard case .captured(let page, _) = stage, !finished else { return nil }
    finished = true
    device.stop()
    return page
  }

  func cancel() {
    finished = true
    device.stop()
  }

  func stopIfRunning() {
    guard !finished else { return }
    finished = true
    device.stop()
  }
}

/// The camera we own, in place of `VNDocumentCameraViewController`: that one
/// fired its own shutter while you were reaching for Save, and kept the first
/// of however many shots it took without saying so (#1460). One press, then the
/// flattened page to approve before it is stored.
struct PageCameraScreen: View {
  let onFinish: (PhotoCapture) -> Void

  /// `@State`, never a plain property: the presenting screens re-evaluate their
  /// bodies on every core update, which re-runs this initialiser while the
  /// cover is up and would otherwise swap in a fresh unconfigured camera.
  @State private var model: PageCameraModel
  /// Shapes the preview box to match the sensor's actual orientation (#1548).
  @State private var previewIsLandscape = false

  init(device: (any PageCameraDevice)? = nil, onFinish: @escaping (PhotoCapture) -> Void) {
    _model = State(initialValue: PageCameraModel(device: device ?? AVPageCameraDevice()))
    self.onFinish = onFinish
  }

  var body: some View {
    ZStack {
      IntradaColor.viewerBackdrop.ignoresSafeArea()
      stageContent
      chrome
    }
    .task { await model.begin() }
    .onDisappear { model.stopIfRunning() }
  }

  @ViewBuilder private var stageContent: some View {
    switch model.stage {
    case .preparing:
      EmptyView()
    case .live:
      if let session = model.session {
        CameraPreview(
          session: session,
          attachPreviewLayer: model.attachPreviewLayer,
          onRotate: { previewIsLandscape = PageCameraModel.isLandscape(angle: $0) }
        )
        .aspectRatio(previewIsLandscape ? 4.0 / 3.0 : 3.0 / 4.0, contentMode: .fit)
      }
    case .captured(let page, let pageFound):
      CapturedPageConfirm(page: page, pageFound: pageFound, onKeep: keep, onRetake: model.retake)
    case .blocked(let access):
      PageCameraBlocked(access: access, onOpenSettings: openSettings)
    case .unstartable:
      PageCameraUnstartable()
    }
  }

  private var chrome: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Cancel", action: cancel)
          .scrimCapsule()
        Spacer()
      }
      .padding(IntradaSpacing.card)

      Spacer()

      if let failure = model.failure {
        PageCameraFailure(message: failure)
          .padding(.bottom, IntradaSpacing.card)
      }

      if case .live = model.stage {
        PageCameraShutter(disabled: model.capturing, onPress: takePhoto)
          .padding(.bottom, IntradaSpacing.section)
      }
    }
  }

  private func takePhoto() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    Task { await model.takePhoto() }
  }

  private func keep() {
    guard let page = model.keep() else { return }
    onFinish(.captured(page))
  }

  private func cancel() {
    model.cancel()
    onFinish(.cancelled)
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

// ── The states, each renderable without a camera ──

struct PageCameraShutter: View {
  let disabled: Bool
  let onPress: () -> Void

  var body: some View {
    Button(action: onPress) {
      ZStack {
        Circle()
          .strokeBorder(IntradaColor.onAccent.opacity(0.6), lineWidth: 3)
          .frame(width: 76, height: 76)
        Circle()
          .fill(IntradaColor.onAccent)
          .frame(width: 62, height: 62)
      }
    }
    .disabled(disabled)
    .accessibilityLabel("Take the photo")
  }
}

/// The page as it will be stored, with the two ways out. Approving
/// what was kept is the whole fix: the scanner discarded shots silently.
struct CapturedPageConfirm: View {
  let page: UIImage
  /// An uncropped page shown without comment reads as the best the app can do
  /// (#1565), so the miss is said out loud.
  let pageFound: Bool
  let onKeep: () -> Void
  let onRetake: () -> Void

  var body: some View {
    VStack(spacing: IntradaSpacing.section) {
      Image(uiImage: page)
        .resizable()
        .scaledToFit()
        .accessibilityLabel("The page you photographed")

      if !pageFound {
        PageCameraFailure(
          message: "Couldn't find the edges of the page. Retake it, or use it as it is."
        )
        .multilineTextAlignment(.center)
        .padding(.horizontal, IntradaSpacing.card)
      }

      HStack(spacing: IntradaSpacing.section) {
        Button("Retake", action: onRetake)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.onAccent)

        Button("Use this photo", action: onKeep)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.onAccent)
          .padding(.horizontal, IntradaSpacing.section)
          .padding(.vertical, IntradaSpacing.cardCompact)
          .background(LinearGradient.brandBar, in: Capsule())
      }
    }
    .padding(.vertical, IntradaSpacing.section)
  }
}

struct PageCameraBlocked: View {
  let access: PageCameraAccess
  let onOpenSettings: () -> Void

  var body: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      Text(access == .denied ? "Camera access is off" : "No camera on this device")
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.onAccent)

      if access == .denied {
        Text("Turn it on in Settings to photograph a page.")
          .font(IntradaFont.body)
          .foregroundStyle(IntradaColor.onAccent.opacity(0.75))
          .multilineTextAlignment(.center)

        Button("Open Settings", action: onOpenSettings)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.onAccent)
          .padding(.horizontal, IntradaSpacing.section)
          .padding(.vertical, IntradaSpacing.cardCompact)
          .background(LinearGradient.brandBar, in: Capsule())
      }
    }
    .padding(IntradaSpacing.section)
  }
}

struct PageCameraUnstartable: View {
  var body: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      Text("Couldn't start the camera")
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.onAccent)

      Text("Something else may be using it. Close this and try again.")
        .font(IntradaFont.body)
        .foregroundStyle(IntradaColor.onAccent.opacity(0.75))
        .multilineTextAlignment(.center)
    }
    .padding(IntradaSpacing.section)
  }
}

struct PageCameraFailure: View {
  let message: String

  var body: some View {
    Text(message)
      .font(IntradaFont.body)
      .foregroundStyle(IntradaColor.onAccent)
      .padding(.horizontal, IntradaSpacing.card)
      .padding(.vertical, IntradaSpacing.controlGap)
      .background(IntradaColor.danger, in: RoundedRectangle(cornerRadius: IntradaRadius.badge))
  }
}

/// `AVCaptureVideoPreviewLayer` is a layer, not a view, so it needs a `UIView`
/// backed by one rather than a sublayer that has to be resized by hand.
private struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession
  let attachPreviewLayer: (AVCaptureVideoPreviewLayer, @escaping (CGFloat) -> Void) -> Void
  let onRotate: (CGFloat) -> Void

  func makeUIView(context _: Context) -> PreviewView {
    let view = PreviewView()
    view.previewLayer?.session = session
    view.previewLayer?.videoGravity = .resizeAspect
    if let previewLayer = view.previewLayer {
      attachPreviewLayer(previewLayer, onRotate)
    }
    return view
  }

  func updateUIView(_ view: PreviewView, context _: Context) {
    view.previewLayer?.session = session
  }
}

private final class PreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
}
