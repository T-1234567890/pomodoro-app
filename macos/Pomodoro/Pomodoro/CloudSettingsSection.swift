import AppKit
import SwiftUI
import Combine

/// User-facing cloud auth section with real Google Sign-In.
struct CloudSettingsSection: View {
    private let disabledMessage = """
    Google Sign-In is coming soon.
    This feature is currently in beta and temporarily disabled.
    """

    @State private var statusMessage: String = CloudAuthEnabled ? "" : """
    Google Sign-In is coming soon.
    This feature is currently in beta and temporarily disabled.
    """
    @State private var isSigningIn = false
    @State private var signedInEmail: String?
    @State private var sessionSnippet: String?

    private let authManager = AuthManager.shared
    private let authStore = AuthStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud (Beta)")
                .font(.title3.bold())

            Text("Sign in with Google to sync with the Pomodoro backend.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusChip

                Spacer()

                signInButton

                Button("Sign out") {
                    signOut()
                }
                .buttonStyle(.bordered)
                .disabled(!(authManager.isAuthenticated) || isSigningIn)
            }

            if let email = signedInEmail {
                Text("Account: \(email)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let snippet = sessionSnippet, authManager.isAuthenticated {
                Text("Session token: \(snippet)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            refreshStatus()
        }
    }

    private var signInButton: some View {
        if CloudAuthEnabled {
            return AnyView(
                Button {
                    Task { await performSignIn() }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text(isSigningIn ? "Signing in..." : "Sign in with Google")
                        if isSigningIn {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.leading, 4)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.22, green: 0.53, blue: 0.96))
                .disabled(isSigningIn)
            )
        } else {
            return AnyView(
                Button {
                } label: {
                    HStack {
                        Image(systemName: "g.circle")
                        Text("Google sign-in coming soon")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primary.opacity(0.15))
                .disabled(true)
            )
        }
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(authManager.isAuthenticated ? Color.green : Color.red.opacity(0.45))
                .frame(width: 10, height: 10)
            Text(authManager.isAuthenticated ? "Signed in" : "Signed out")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func signOut() {
        authManager.logout()
        signedInEmail = nil
        sessionSnippet = nil
        statusMessage = "Signed out."
    }

    private func refreshStatus() {
        if !CloudAuthEnabled {
            statusMessage = disabledMessage
            return
        }
        let current = authStore.loadSession()
        if let current {
            sessionSnippet = tokenPreview(from: current.accessToken)
            statusMessage = "Session token stored in Keychain."
        } else {
            statusMessage = "Not signed in."
        }
    }

    @MainActor
    private func performSignIn() async {
        guard CloudAuthEnabled else {
            statusMessage = disabledMessage
            return
        }
        guard !isSigningIn else { return }

        isSigningIn = true
        statusMessage = "Opening Google sign-in…"

        do {
            let outcome = try await authManager.signIn(presentingWindow: currentWindow())
            signedInEmail = outcome.email
            sessionSnippet = tokenPreview(from: outcome.idToken ?? outcome.accessToken)
            statusMessage = "Signed in."
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSigningIn = false
    }

    private func tokenPreview(from token: String?) -> String? {
        guard let token, !token.isEmpty else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private func currentWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
    }
}

#Preview {
    CloudSettingsSection()
        .frame(width: 520)
}
