import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var showLogin = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = auth.currentUser {
                    signedIn(user)
                } else {
                    signedOut
                }
            }
            .background(Theme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogin) { AuthSheet() }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete My Account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your Potluck account and personal data. Transaction records required by law are retained, then purged. This cannot be undone.")
            }
            .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await auth.deleteAccount()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func signedIn(_ user: User) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                AvatarView(url: user.avatarUrl, initials: user.initials, size: 88)
                Text(user.fullName).font(.title2.bold()).foregroundStyle(Theme.ink)
                Text(user.email).font(.subheadline).foregroundStyle(Theme.mutedInk)
                Pill(text: user.role.capitalized, filled: true)
            }
            .padding(.top, 24)

            VStack(spacing: 0) {
                settingsRow("heart", "Saved Chefs")
                Divider().padding(.leading, 52)
                settingsRow("creditcard", "Payment Methods")
                Divider().padding(.leading, 52)
                settingsRow("bell", "Notifications")
                Divider().padding(.leading, 52)
                settingsRow("questionmark.circle", "Help & Support")
            }
            .potluckCard()
            .padding(.horizontal)

            Button(role: .destructive) { auth.signOut() } label: {
                Text("Sign Out").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .background(Color.white).foregroundStyle(Theme.terracotta)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            Button { showDeleteConfirm = true } label: {
                HStack(spacing: 6) {
                    if auth.isWorking { ProgressView().tint(.red) }
                    Text("Delete Account")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .disabled(auth.isWorking)
            .foregroundStyle(.red)
            .padding(.horizontal)

            Text("Permanently deletes your account and data.")
                .font(.caption2).foregroundStyle(Theme.mutedInk)

            Text("Potluck v1.0").font(.caption2).foregroundStyle(Theme.mutedInk).padding(.top, 8)
        }
        .padding(.bottom, 32)
    }

    private var signedOut: some View {
        VStack(spacing: 18) {
            BrandMark().padding(.top, 40)
            Text("Home-cooked meals,\nmade with love.")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text("Sign in to book unique dining experiences with talented home chefs across Singapore.")
                .font(.subheadline).foregroundStyle(Theme.mutedInk)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Sign In or Register") { showLogin = true }
                .buttonStyle(PrimaryButton()).padding(.horizontal, 40).padding(.top, 8)
        }
    }

    private func settingsRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.teal).frame(width: 24)
            Text(title).font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mutedInk)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
