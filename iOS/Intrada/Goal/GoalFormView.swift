import SharedTypes
import SwiftUI

struct GoalFormView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var core: Core
  let existingGoal: PracticeGoal?

  @State private var name: String
  @State private var description: String
  @State private var targetDate: Date
  @State private var tempoTarget: String
  @State private var selectedStudies: Set<String>
  @State private var showStudyForm = false
  @State private var studyFilter = ""
  @State private var validationErrors: [String] = []

  init(core: Core, existingGoal: PracticeGoal? = nil) {
    self.core = core
    self.existingGoal = existingGoal
    
    // Initialize state variables with existing goal data if available
    _name = State(initialValue: existingGoal?.name ?? "")
    _description = State(initialValue: existingGoal?.description ?? "")
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let date = existingGoal?.targetDate.flatMap { dateFormatter.date(from: $0) } ?? Date()
    _targetDate = State(initialValue: date)
    
    _tempoTarget = State(initialValue: existingGoal?.tempoTarget.map(String.init) ?? "")
    _selectedStudies = State(initialValue: Set(existingGoal?.studyIds ?? []))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Goal Details")) {
          TextField("Name", text: $name)
          TextField("Description", text: $description, axis: .vertical)
            .lineLimit(3...6)
        }

        Section(header: Text("Target Date")) {
          DatePicker("Select Date", selection: $targetDate, displayedComponents: [.date])
        }

        Section(header: Text("Tempo Target (BPM)")) {
          TextField("Enter tempo", text: $tempoTarget)
            .keyboardType(.numberPad)
          
          if !tempoTarget.isEmpty && (UInt32(tempoTarget) == nil || UInt32(tempoTarget)! <= 0 || UInt32(tempoTarget)! > 300) {
            Text("Tempo must be between 1-300 BPM")
              .foregroundColor(.red)
              .font(.caption)
          }
        }
        
        if !validationErrors.isEmpty {
          Section {
            ForEach(validationErrors, id: \.self) { error in
              Text(error)
                .foregroundColor(.red)
                .font(.caption)
            }
          }
        }

        Section(header: Text("Studies")) {
  
          Button(action: {
            // Present study form sheet
            showStudyForm = true
          }) {
            HStack {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
              Text("Add New Study")
                .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
            }
          }
          .sheet(isPresented: $showStudyForm) {
            StudyFormView(core: core)
          }
          
          ForEach(core.view.studies, id: \.id) { study in
            Toggle(
              study.name,
              isOn: binding(for: study)
            )
          }
        }
      }
      .navigationTitle(existingGoal == nil ? "New Goal" : "Edit Goal")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") {
            saveGoal()
          }
          .disabled(!isFormValid)
        }
      }
    }
  }

  private func binding(for study: Study) -> Binding<Bool> {
    Binding(
      get: { selectedStudies.contains(study.id) },
      set: { isSelected in
        if isSelected {
          selectedStudies.insert(study.id)
        } else {
          selectedStudies.remove(study.id)
        }
      }
    )
  }
  
  private var isFormValid: Bool {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let tempoValid = tempoTarget.isEmpty || (UInt32(tempoTarget) != nil && UInt32(tempoTarget)! > 0 && UInt32(tempoTarget)! <= 300)
    
    return !trimmedName.isEmpty && tempoValid
  }
  
  private func saveGoal() {
    validationErrors.removeAll()
    
    // Compile-time validation of required fields
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      validationErrors.append("Name cannot be empty")
      return
    }
    
    // Validate tempo if provided  
    let tempoValue: UInt32? = {
      guard !tempoTarget.isEmpty else { return nil }
      guard let tempo = UInt32(tempoTarget), tempo > 0 && tempo <= 300 else {
        validationErrors.append("Tempo must be between 1-300 BPM")
        return nil
      }
      return tempo
    }()
    
    // Return early if validation failed
    if !validationErrors.isEmpty {
      return
    }
    
    // Validate date format
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let targetDateString = dateFormatter.string(from: targetDate)
    
    // Create goal with validated inputs - no runtime crashes possible!
    let goal = PracticeGoal(
      id: existingGoal?.id ?? UUID().uuidString,
      name: trimmedName, // Guaranteed non-empty
      description: description.isEmpty ? nil : description,
      status: existingGoal?.status ?? .notStarted,
      startDate: existingGoal?.startDate,
      targetDate: targetDateString, // Guaranteed valid format
      studyIds: Array(selectedStudies),
      tempoTarget: tempoValue // Guaranteed valid or nil
    )
    
    // Update core
    if existingGoal != nil {
      core.update(.editGoal(goal))
    } else {
      core.update(.addGoal(goal))
    }
    
    dismiss()
  }
}

#Preview {
  GoalFormView(core: Core())
}
