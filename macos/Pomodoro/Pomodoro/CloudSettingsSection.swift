import SwiftUI
import FirebaseAuth

struct CloudSettingsSection: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AuthMode = .signIn

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.title3.bold())

            Text("Login is optional. Sign in to unlock premium features.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if authViewModel.isLoggedIn {
                loggedInSection
            } else {
                loginSection
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
    }

    private var loggedInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatarView(url: authViewModel.user?.photoURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(authViewModel.user?.displayName ?? "Signed in")
                        .font(.headline)
                    Text(authViewModel.currentUserEmail.isEmpty ? "No email provided" : authViewModel.currentUserEmail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusChip(isLoggedIn: true)
            }

            Button("Logout") {
                authViewModel.signOut()
            }
            .buttonStyle(.bordered)
            .disabled(authViewModel.isLoading)
        }
    }

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusChip(isLoggedIn: false)
                Spacer()
            }

            Picker("Mode", selection: $mode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Sign Up").tag(AuthMode.signUp)
            }
            .pickerStyle(.segmented)

            Button {
                Task {
                    do {
                        try await authViewModel.signInWithGoogle()
                        clearCredentials()
                    } catch {
                        return
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                    Text(mode == .signUp ? "Continue with Google" : "Sign in with Google")
                    Spacer()
                    if authViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authViewModel.isLoading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .disabled(authViewModel.isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .disabled(authViewModel.isLoading)
            }

            Button {
                Task {
                    do {
                        switch mode {
                        case .signIn:
                            try await authViewModel.signInWithEmail(email: email, password: password)
                        case .signUp:
                            try await authViewModel.signUpWithEmail(email: email, password: password)
                        }
                        clearCredentials()
                    } catch {
                        return
                    }
                }
            } label: {
                HStack {
                    Text(mode == .signUp ? "Create Account" : "Sign In with Email")
                    Spacer()
                    if authViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(authViewModel.isLoading || !canSubmitEmailPassword)

            if let error = authViewModel.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func statusChip(isLoggedIn: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isLoggedIn ? Color.green : Color.orange.opacity(0.65))
                .frame(width: 10, height: 10)
            Text(isLoggedIn ? "Logged in" : "Optional login")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func avatarView(url: URL?) -> some View {
        let fallback = Circle()
            .fill(Color.primary.opacity(0.1))
            .overlay {
                if let initial = userInitial {
                    Text(initial)
                        .font(.headline.weight(.semibold))
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
            }

        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    fallback
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                case .failure:
                    fallback
                @unknown default:
                    fallback
                }
            }
            .frame(width: 40, height: 40)
        } else {
            fallback
                .frame(width: 40, height: 40)
        }
    }

    private var canSubmitEmailPassword: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private var userInitial: String? {
        if let name = authViewModel.user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           let first = name.first {
            return String(first).uppercased()
        }
        if let first = authViewModel.currentUserEmail.first {
            return String(first).uppercased()
        }
        return nil
    }

    private func clearCredentials() {
        email = ""
        password = ""
    }
}

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CloudSettingsSection()
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520)
    }
}

private enum AuthMode {
    case signIn
    case signUp
}

#Preview {
    CloudSettingsSection()
        .frame(width: 520)
        .environmentObject(AuthViewModel.shared)
}
