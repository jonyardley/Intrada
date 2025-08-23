import SharedTypes
import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var core: Core
    let goal: PracticeGoal
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if let description = goal.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)

                // Target Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Date")
                        .font(.headline)

                    if let targetDate = goal.targetDate {
                        Text(targetDate)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)

                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)

                    StatusBadge(status: goal.status)
                }
                .padding(.horizontal)

                // Associated Studies
                VStack(alignment: .leading, spacing: 8) {
                    Text("Studies")
                        .font(.headline)

                    let studies = core.view.studies.filter { study in
                        goal.studyIds.contains(study.id)
                    }

                    if studies.isEmpty {
                        Text("No studies added")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        ForEach(studies, id: \.id) { study in
                            HStack {
                                Text(study.name)
                                Spacer()
                                if let description = study.description {
                                    Text(description)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            GoalFormView(core: core, existingGoal: goal)
        }
    }
}

#Preview {
    GoalDetailView(
        core: Core(),
        goal: PracticeGoal(
            id: "1",
            name: "Sample Goal",
            description: "This is a sample goal",
            status: .inProgress,
            startDate: nil,
            targetDate: "2025-05-01",
            studyIds: [],
            tempoTarget: nil
        )
    )
}
