import SharedTypes
import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingEditForm = false
    @State private var showingReflectionForm = false
    @State private var showingError = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var session: PracticeSession? {
        core.view.sessions.first(where: { $0.id == sessionId })
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                        SessionHeaderView(session: session)
                        SessionSummaryView(session: session)
                        SessionNotesView(session: session)
                        SessionTimesView(session: session)
                        SessionRelatedGoalsView(session: session, core: core)
                    }
                    .padding(.vertical, Theme.Spacing.large)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        SessionStateTransitionButton(
                            session: session,
                            onStart: { startSession(session) },
                            onEnd: { endSession(session) },
                            onReflect: { showingReflectionForm = true }
                        )

                        Button("Edit") {
                            showingEditForm = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditForm) {
                    SessionFormView(
                        core: core,
                        isPresented: $showingEditForm,
                        existingSessionId: sessionId
                    )
                }
                .sheet(isPresented: $showingReflectionForm) {
                    SessionReflectionForm(
                        sessionId: session.id,
                        core: core,
                        isPresented: $showingReflectionForm
                    )
                }
                .alert("Session Error", isPresented: $showingError) {
                    Button("OK") {}
                } message: {
                    Text(errorMessage)
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.3))
                    }
                }
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Text("Session not found")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.text)
                        .padding(.top, Theme.Spacing.small)

                    Text("This session may have been deleted or doesn't exist.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.extraLarge)
                        .padding(.top, Theme.Spacing.extraSmall)

                    Button("Go Back") {
                        dismiss()
                    }
                    .padding(.top, Theme.Spacing.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
            }
        }
    }

    // MARK: - Actions

    private func startSession(_ session: PracticeSession) {
        isLoading = true
        let startTime = Date().ISO8601Format()
        core.update(.session(.startSession(session.id, startTime)))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }

    private func endSession(_ session: PracticeSession) {
        isLoading = true
        let endTime = Date().ISO8601Format()
        core.update(.session(.endSession(session.id, endTime)))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}
