import SwiftUI
import SharedTypes

struct StudiesView: View {
    @ObservedObject var core: Core
    @State private var showingAddForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your Studies")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddForm = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
                .padding(.horizontal)
                
                // Studies section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Studies")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if core.view.studies.isEmpty {
                        Text("No studies yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    } else {
                        ForEach(core.view.studies, id: \.id) { study in
                            NavigationLink(destination: StudyDetailView(core: core, study: study)) {
                                StudyCard(study: study)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Studies")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddForm) {
            StudyFormView(core: core)
        }
    }
}

struct StudyCard: View {
    let study: Study
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(study.name)
                .font(.headline)
            
            if let description = study.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    StudiesView(core: Core())
} 
