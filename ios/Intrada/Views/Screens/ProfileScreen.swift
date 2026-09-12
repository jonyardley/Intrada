import SharedTypes
import SwiftUI

/// Who is practising: pushed from the Practice header, Edit opens a sheet
/// the way an item page does (#1692). Everything shown comes from the core's
/// profile view; the screen decides nothing.
struct ProfileScreen: View {
  @Environment(Store.self) private var store
  @State private var editing = false

  private var profile: ProfileView? { store.viewModel?.profile }

  var body: some View {
    ZStack {
      PaperBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.section) {
          hero
          highlighter
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.bottom, IntradaSpacing.section)
      }
    }
    .navigationTitle("Profile")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") { editing = true }
      }
    }
    .sheet(isPresented: $editing) {
      ProfileEditSheet()
        .environment(store)
    }
  }

  private var hero: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      ProfileBadge(icon: profile?.icon ?? .other, size: IntradaGlyph.hero)
      VStack(spacing: 4) {
        if let name = profile?.name, !name.isEmpty {
          Text(name)
            .font(IntradaFont.pageTitle())
            .foregroundStyle(IntradaColor.ink)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .markerSwipe()
        } else {
          Text("Add your name")
            .font(IntradaFont.pageTitle())
            .foregroundStyle(IntradaColor.inkSecondary)
        }
        Text(instrumentLine)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, IntradaSpacing.section)
    .padding(.bottom, IntradaSpacing.controlGap)
    .accessibilityElement(children: .combine)
  }

  private var instrumentLine: String {
    if let instrument = profile?.instrument, !instrument.isEmpty { return instrument }
    return "What you play"
  }

  private var highlighter: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("Highlighter")
      HStack(spacing: IntradaSpacing.cardCompact) {
        Circle()
          .fill(IntradaColor.marker(profile?.colour ?? .butter))
          .frame(width: 22, height: 22)
        Text((profile?.colour ?? .butter).label)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.ink)
        Spacer(minLength: 0)
      }
      .padding(.vertical, IntradaSpacing.cardCompact)
      .padding(.horizontal, IntradaSpacing.card)
      .cardSurface()
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Highlighter, \((profile?.colour ?? .butter).label)")
    }
  }
}

#if DEBUG
  #Preview("Populated") {
    NavigationStack { ProfileScreen() }
      .environment(Store.previewProfile)
  }

  #Preview("Empty") {
    NavigationStack { ProfileScreen() }
      .environment(Store.preview)
  }
#endif
