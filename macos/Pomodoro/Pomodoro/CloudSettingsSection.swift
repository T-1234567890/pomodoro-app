import AppKit
import FirebaseAuth
import SwiftUI

enum AuthProvider: CaseIterable, Identifiable {
    case google
    case github
    case apple
    case email

    var id: Self { self }

    var title: String {
        switch self {
        case .google:
            return "Continue with Google"
        case .github:
            return "Continue with GitHub"
        case .apple:
            return "Continue with Apple"
        case .email:
            return "Continue with Email"
        }
    }
}

struct CloudSettingsSection: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.text("settings.account.title"))
                .font(.title3.bold())

            if authViewModel.isLoggedIn {
                loggedInSection
            } else {
                LoginView()
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
                    Text(authViewModel.user?.displayName ?? localizationManager.text("settings.account.signed_in"))
                        .font(.headline)
                    Text(authViewModel.currentUserEmail.isEmpty ? localizationManager.text("settings.account.no_email") : authViewModel.currentUserEmail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusChip(isLoggedIn: true)
            }

            Button(localizationManager.text("settings.account.logout")) {
                authViewModel.signOut()
            }
            .buttonStyle(.bordered)
            .disabled(authViewModel.isLoading)
        }
    }

    private func statusChip(isLoggedIn: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isLoggedIn ? Color.green : Color.orange.opacity(0.65))
                .frame(width: 10, height: 10)
            Text(isLoggedIn ? localizationManager.text("settings.account.logged_in") : localizationManager.text("settings.account.optional_login"))
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
}

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showEmailLogin = false
    @State private var showAppleComingSoon = false
    @State private var providerErrorMessage: String?
    @State private var activeProvider: AuthProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AuthProviderButton(provider: .google, isLoading: activeProvider == .google) {
                Task { @MainActor in
                    await performProviderSignIn(provider: .google) {
                        _ = try await AuthManager.shared.signInWithGoogle()
                    }
                }
            }

            AuthProviderButton(provider: .github, isLoading: activeProvider == .github) {
                Task { @MainActor in
                    await performProviderSignIn(provider: .github) {
                        _ = try await AuthManager.shared.signInWithGithub()
                    }
                }
            }

            AuthProviderButton(provider: .apple, isLoading: false) {
                showAppleComingSoon = true
            }

            AuthProviderButton(provider: .email, isLoading: false) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showEmailLogin.toggle()
                }
            }

            if showEmailLogin {
                EmailLoginView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let message = providerErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let message = authViewModel.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .alert("Sign in with Apple", isPresented: $showAppleComingSoon) {
            Button(localizationManager.text("common.close"), role: .cancel) {}
        } message: {
            Text("Sign in with Apple – Coming Soon")
        }
    }

    @MainActor
    private func performProviderSignIn(
        provider: AuthProvider,
        _ operation: @escaping @MainActor () async throws -> Void
    ) async {
        providerErrorMessage = nil
        activeProvider = provider
        defer { activeProvider = nil }
        do {
            try await operation()
        } catch {
            providerErrorMessage = (error as NSError).localizedDescription
        }
    }
}

struct AuthProviderButton: View {
    let provider: AuthProvider
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AuthProviderIcon(provider: provider)

                Text(provider.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                if isLoading, provider == .google || provider == .github {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading && (provider == .google || provider == .github))
    }
}

struct EmailLoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(localizationManager.text("auth.email.placeholder"), text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .disabled(authViewModel.isLoading)

            SecureField(localizationManager.text("auth.password.placeholder"), text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .disabled(authViewModel.isLoading)

            Button(localizationManager.text("auth.signin_email")) {
                Task { @MainActor in
                    do {
                        try await authViewModel.signInWithEmail(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                        password = ""
                    } catch {
                        return
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authViewModel.isLoading || !canSubmit)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }
}

private struct AuthProviderIcon: View {
    let provider: AuthProvider

    var body: some View {
        Group {
            switch provider {
            case .google:
                Image("GoogleLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .github:
                Image("GitHubLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .apple:
                Image(systemName: "applelogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            case .email:
                Image(systemName: "envelope")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 18, height: 18)
    }
}

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CloudSettingsSection()
            HStack {
                Spacer()
                Button(localizationManager.text("common.close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520)
    }
}

#Preview {
    CloudSettingsSection()
        .frame(width: 520)
        .environmentObject(AuthViewModel.shared)
        .environmentObject(LocalizationManager.shared)
}
