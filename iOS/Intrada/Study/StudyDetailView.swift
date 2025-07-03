import SwiftUI
import SharedTypes

struct StudyDetailView: View {
    @ObservedObject var core: Core
    let study: Study
    @State private var showingEditForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Study Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(study.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let description = study.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Associated Goals
                VStack(alignment: .leading, spacing: 8) {
                    Text("Related Goals")
                        .font(.headline)
                    
                    let goals = core.view.goals.filter { goal in
                        goal.studyIds.contains(study.id)
                    }
                    
                    if goals.isEmpty {
                        Text("No goals associated")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        ForEach(goals, id: \.id) { goal in
                            NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
                                HStack {
                                    Text(goal.name)
                                    Spacer()
                                    if let description = goal.description {
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
            StudyFormView(core: core, existingStudy: study)
        }
    }
}

#Preview {
    StudyDetailView(
        core: Core(),
        study: Study(
            id: "1",
            name: "Sample Study",
            description: "This is a sample study"
        )
    )
} 