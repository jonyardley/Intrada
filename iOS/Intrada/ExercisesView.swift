import SwiftUI
import SharedTypes

struct ExercisesView: View {
    @ObservedObject var core: Core
    
    var body: some View {
        List(core.view.exercises, id: \.id) { exercise in
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name)
                    .font(.headline)
                
                if let description = exercise.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Exercises")
    }
}

#Preview {
    ExercisesView(core: Core())
} 
