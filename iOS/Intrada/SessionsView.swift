//
//  SessionsView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SwiftUI

struct Session: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let notes: String
}

struct SessionsView: View {
    @State private var sessions: [Session] = []
    @State private var showingNewSessionSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                Button(action: {
                    showingNewSessionSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingNewSessionSheet) {
                NewSessionView(sessions: $sessions)
            }
        }
    }
}

struct SessionRow: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.date, style: .date)
                .font(.headline)
            Text("Duration: \(formatDuration(session.duration))")
                .font(.subheadline)
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
}

struct NewSessionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var sessions: [Session]
    @State private var notes = ""
    @State private var duration: TimeInterval = 3600 // Default 1 hour
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    TextField("Notes", text: $notes)
                    Stepper("Duration: \(formatDuration(duration))", value: $duration, in: 300...7200, step: 300)
                }
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newSession = Session(date: Date(), duration: duration, notes: notes)
                        sessions.append(newSession)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    SessionsView()
}

