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
                paymentsInfoRow
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

            Text("Potluck v\(appVersion)").font(.caption2).foregroundStyle(Theme.mutedInk).padding(.top, 8)
        }
        .padding(.bottom, 32)
    }

    private var signedOut: some View {
        VStack(spacing: 18) {
            BrandMark().padding(.top, 40)
            Text("Home-cooked meals,\nfrom real Singapore kitchens.")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text("From Peranakan feasts in Joo Chiat to nasi lemak in Geylang Serai — book a seat at a home chef's table, or have them cook a private dinner at yours.")
                .font(.subheadline).foregroundStyle(Theme.mutedInk)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Sign In or Register") { showLogin = true }
                .buttonStyle(PrimaryButton()).padding(.horizontal, 40).padding(.top, 8)

            VStack(spacing: 0) {
                howItWorksRow("1", "magnifyingglass", "Discover",
                              "Browse home chefs by cuisine, neighbourhood and date.")
                Divider().padding(.leading, 52)
                howItWorksRow("2", "calendar", "Book",
                              "Pick your date, menu and party size. Pay securely in SGD.")
                Divider().padding(.leading, 52)
                howItWorksRow("3", "fork.knife", "Makan",
                              "Pull up a chair at the chef's table for a proper home-cooked spread.")
            }
            .potluckCard()
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func howItWorksRow(_ number: String, _ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.terracotta).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Informational row — payment happens per-booking at checkout, so there is
    /// no stored payment method to manage.
    private var paymentsInfoRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "creditcard").foregroundStyle(Theme.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Payments").font(.subheadline)
                Text("Card, PayPal & PayNow at checkout").font(.caption).foregroundStyle(Theme.mutedInk)
            }
            Spacer()
        }
        .padding(16)
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
