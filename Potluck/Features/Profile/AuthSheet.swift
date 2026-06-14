import SwiftUI

/// Combined sign-in / register sheet.
struct AuthSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    enum Mode { case login, register }
    @State private var mode: Mode = .login

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BrandMark().padding(.top, 8)

                    Picker("", selection: $mode) {
                        Text("Sign In").tag(Mode.login)
                        Text("Register").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        if mode == .register {
                            HStack(spacing: 12) {
                                field("First name", text: $firstName)
                                field("Last name", text: $lastName)
                            }
                        }
                        field("Email", text: $email, keyboard: .emailAddress, autocaps: false)
                        secureField("Password", text: $password)
                    }

                    if let error {
                        Text(error).font(.caption).foregroundStyle(Theme.terracotta)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if auth.isWorking { ProgressView().tint(.white) }
                        else { Text(mode == .login ? "Sign In" : "Create Account") }
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(auth.isWorking || !isValid)

                    Text("By continuing you agree to Potluck's Terms of Service and Privacy Policy.")
                        .font(.caption2).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(mode == .login ? "Welcome back" : "Join Potluck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var isValid: Bool {
        if mode == .register {
            return !firstName.isEmpty && !lastName.isEmpty && email.contains("@") && password.count >= 8
        }
        return email.contains("@") && !password.isEmpty
    }

    private func submit() async {
        error = nil
        do {
            if mode == .login {
                try await auth.login(email: email, password: password)
            } else {
                try await auth.register(email: email, password: password, firstName: firstName, lastName: lastName)
            }
            dismiss()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default, autocaps: Bool = true) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocaps ? .words : .never)
            .autocorrectionDisabled()
            .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Small rainbow + spoon wordmark used on auth and profile screens.
struct BrandMark: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().trim(from: 0.5, to: 1).stroke(Theme.golden, style: .init(lineWidth: 8, lineCap: .round))
                    .frame(width: 76, height: 76)
                Circle().trim(from: 0.5, to: 1).stroke(Theme.teal, style: .init(lineWidth: 8, lineCap: .round))
                    .frame(width: 52, height: 52)
                Image(systemName: "fork.knife").font(.system(size: 18)).foregroundStyle(Theme.terracotta)
                    .offset(y: 4)
            }
            .frame(height: 50)
            Text("Potluck").font(.title2.bold()).foregroundStyle(Theme.ink)
        }
    }
}
