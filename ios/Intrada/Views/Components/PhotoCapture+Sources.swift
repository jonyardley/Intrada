import PhotosUI
import SwiftUI

/// What a capture route hands back.
enum PhotoCapture {
  case captured(UIImage)
  case cancelled
}

/// Which capture route is on screen. Driven by `.photoCapture(...)`, which
/// owns the dismissal the camera does not do itself: forgetting that once
/// left the scanner with no way out (#1436).
struct PhotoCaptureState {
  fileprivate(set) var scanning = false
  fileprivate(set) var choosingFromLibrary = false
  fileprivate var picked: PhotosPickerItem?

  mutating func scan() { scanning = true }
  mutating func chooseFromLibrary() { choosingFromLibrary = true }
}

extension View {
  func photoCapture(_ state: Binding<PhotoCaptureState>, using sources: PhotoCaptureSources)
    -> some View
  {
    fullScreenCover(isPresented: state.scanning) {
      PageCameraScreen { capture in
        state.wrappedValue.scanning = false
        Task { await sources.finished(scanning: capture) }
      }
    }
    .photosPicker(
      isPresented: state.choosingFromLibrary, selection: state.picked, matching: .images
    )
    .onChange(of: state.wrappedValue.picked) { _, item in
      guard let item else { return }
      state.wrappedValue.picked = nil
      Task { await sources.loaded(item) }
    }
  }
}

/// The capture half of a photo surface, shared by `PhotoCard` (the photo on a
/// piece) and `ScanPageEntry` (the photo the add form is read from), which
/// otherwise duplicate every step of it.
@MainActor
struct PhotoCaptureSources {
  let onCaptured: (String) -> Void
  /// Takes a message written for the user, never a raw error.
  let onFailure: (String) -> Void

  static var canScan: Bool { AVPageCameraDevice.isAvailable }

  func finished(scanning capture: PhotoCapture) async {
    switch capture {
    case .captured(let image): await write(image)
    case .cancelled: break
    }
  }

  func loaded(_ item: PhotosPickerItem) async {
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        onFailure("Couldn't read that photo. Try another.")
        return
      }
      // The scanner route arrives cropped; a library photo does not, and the
      // work blocks long enough to drop frames. A chosen photo often has no
      // page edges to find (a screenshot of a PDF), so a miss stays silent here (#1565).
      let page = await Task.detached(priority: .userInitiated) { PageCrop.toPage(image).image }
        .value
      await write(page)
    } catch {
      report(error, "photo library load")
      onFailure("Couldn't read that photo. Try another.")
    }
  }

  /// Bytes first, then whoever names them. The order is the whole point: an
  /// item can never end up naming a file that was never written.
  ///
  /// Off the main actor: the downscale and JPEG encode of a 12MP library photo
  /// hitched the picker's dismissal (#1450).
  private func write(_ image: UIImage) async {
    let photoId = Ulid.generate()
    do {
      try await Task.detached(priority: .userInitiated) {
        _ = try PhotoFileStore.write(image, id: photoId)
      }.value
    } catch {
      report(error, "photo write")
      onFailure("Couldn't save the photo. Try again.")
      return
    }
    onCaptured(photoId)
  }
}
