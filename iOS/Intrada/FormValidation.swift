import Foundation

// MARK: - Form Validation Framework

protocol FormValidator {
    func validate() -> FormValidationResult
}

struct FormValidationResult {
    let isValid: Bool
    let errors: [String]

    static let valid = FormValidationResult(isValid: true, errors: [])

    static func invalid(with errors: [String]) -> FormValidationResult {
        FormValidationResult(isValid: false, errors: errors)
    }

    static func invalid(with error: String) -> FormValidationResult {
        FormValidationResult(isValid: false, errors: [error])
    }
}

// MARK: - Field Validators

enum FieldValidator {
    static func required(_ value: String, fieldName: String) -> FormValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ?
            .invalid(with: "\(fieldName) cannot be empty") :
            .valid
    }

    static func tempo(_ value: String) -> FormValidationResult {
        guard !value.isEmpty else { return .valid } // Optional field

        guard let tempo = UInt32(value), tempo > 0, tempo <= 300 else {
            return .invalid(with: "Tempo must be between 1-300 BPM")
        }

        return .valid
    }

    static func minLength(_ value: String, min: Int, fieldName: String) -> FormValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count < min ?
            .invalid(with: "\(fieldName) must be at least \(min) characters") :
            .valid
    }

    static func maxLength(_ value: String, max: Int, fieldName: String) -> FormValidationResult {
        value.count > max ?
            .invalid(with: "\(fieldName) must be less than \(max) characters") :
            .valid
    }

    static func combine(_ results: [FormValidationResult]) -> FormValidationResult {
        let errors = results.flatMap(\.errors)
        return errors.isEmpty ? .valid : .invalid(with: errors)
    }
}

// MARK: - Goal Form Validator

struct GoalFormValidator: FormValidator {
    let name: String
    let description: String
    let tempoTarget: String

    func validate() -> FormValidationResult {
        let results = [
            FieldValidator.required(name, fieldName: "Name"),
            FieldValidator.maxLength(name, max: 100, fieldName: "Name"),
            FieldValidator.maxLength(description, max: 500, fieldName: "Description"),
            FieldValidator.tempo(tempoTarget)
        ]

        return FieldValidator.combine(results)
    }
}

// MARK: - Study Form Validator

struct StudyFormValidator: FormValidator {
    let name: String
    let description: String

    func validate() -> FormValidationResult {
        let results = [
            FieldValidator.required(name, fieldName: "Name"),
            FieldValidator.maxLength(name, max: 100, fieldName: "Name"),
            FieldValidator.maxLength(description, max: 500, fieldName: "Description")
        ]

        return FieldValidator.combine(results)
    }
}

// MARK: - Session Form Validator

struct SessionFormValidator: FormValidator {
    let intention: String
    let notes: String

    func validate() -> FormValidationResult {
        let results = [
            FieldValidator.required(intention, fieldName: "Intention"),
            FieldValidator.maxLength(intention, max: 200, fieldName: "Intention"),
            FieldValidator.maxLength(notes, max: 1000, fieldName: "Notes")
        ]

        return FieldValidator.combine(results)
    }
}

// MARK: - Form State Manager

@MainActor
class FormStateManager<T: FormValidator>: ObservableObject {
    @Published var validationErrors: [String] = []
    @Published var isValid: Bool = false

    private let validator: T

    init(validator: T) {
        self.validator = validator
    }

    func validateForm() {
        let result = validator.validate()
        validationErrors = result.errors
        isValid = result.isValid
    }

    func clearErrors() {
        validationErrors.removeAll()
        isValid = false
    }
}
