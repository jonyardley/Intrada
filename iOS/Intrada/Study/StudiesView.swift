import SharedTypes
import SwiftUI

struct StudiesView: View {
    @ObservedObject var core: Core
    @State private var showingAddForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                ListHeader(title: "Your Studies") {
                    showingAddForm = true
                }

                studiesSection
            }
            .padding(.vertical, Theme.Spacing.large)
        }
        .navigationTitle("Studies")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddForm) {
            StudyFormView(core: core)
        }
    }

    private var studiesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SectionHeader(title: "Your Studies")

            if core.view.studies.isEmpty {
                EmptyStateView(message: "No studies yet")
            } else {
                ForEach(core.view.studies, id: \.id) { study in
                    NavigationLink(destination: StudyDetailView(core: core, study: study)) {
                        StudyCard(study: study)
                            .padding(.horizontal, Theme.Spacing.large)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct StudyCard: View {
    let study: Study

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(study.name)
                    .font(Theme.Typography.headline)

                if let description = study.description {
                    Text(description)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    StudiesView(core: Core())
}
