//
//  SessionsView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SwiftUI
import SharedTypes

struct SessionsView: View {
    @ObservedObject var core: Core
    @State private var showingAddForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your Sessions")
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
                
                // Sessions section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent practice sessions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)

                    let sessions = core.view.sessions;
                    
                    if sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ForEach(sessions, id: \.id) { session in
                            SessionRow(session: session)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddForm) {
            // TODO: Add SessionFormView when implemented
            Text("Session Form Coming Soon")
        }
    }
}

struct SessionRow: View {
    let session: PracticeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Intention
            Text(session.intention)
                .font(.headline)
            
            // Notes
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Date, Time and Duration
            HStack {
                if let startTime = session.startTime {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(startTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatTime(startTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if let duration = calculateDuration(start: session.startTime, end: session.endTime) {
                    Text(duration)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func calculateDuration(start: String?, end: String?) -> String? {
        guard let startTime = start, let endTime = end else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let startDate = formatter.date(from: startTime),
              let endDate = formatter.date(from: endTime) else {
            return nil
        }
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: startDate, to: endDate)
        if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        return nil
    }
}

#Preview {
    SessionsView(core: Core())
}

