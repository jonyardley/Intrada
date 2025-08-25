import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(25)
                            .foregroundColor(.gray)
                    }

                    Text("User Name")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("user@example.com")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()

                // Settings sections
                VStack(spacing: 0) {
                    SettingsRow(icon: "person.fill", title: "Edit Profile")
                    SettingsRow(icon: "bell.fill", title: "Notifications")
                    SettingsRow(icon: "lock.fill", title: "Privacy")
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support")
                    SettingsRow(icon: "gear", title: "Settings")
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)

                // Sign out button
                Button {
                    // Add sign out action here
                } label: {
                    Text("Sign Out")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 30)

            Text(title)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
    }
}

#Preview {
    ProfileView()
}
