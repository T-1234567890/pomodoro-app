import SwiftUI

struct LoginView: View {
    @State private var isLoading = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Welcome back")
                    .font(.title2.weight(.semibold))
                Text("Choose a provider to sign in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(Provider.allCases) { provider in
                Button {
                    Task { await attemptLogin(provider) }
                } label: {
                    HStack {
                        Text(provider.buttonTitle)
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(provider.tint)
                .disabled(isLoading)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
    }

    @MainActor
    private func attemptLogin(_ provider: Provider) async {
        guard !isLoading else { return }
        isLoading = true
        statusMessage = nil

        do {
            let jwt = try await AuthService.shared.login(
                provider: provider.rawValue,
                token: provider.fakeToken
            )
            statusMessage = "Signed in via \(provider.displayName). JWT: \(jwt)"
        } catch {
            let localized = (error as? LocalizedError)?.errorDescription
            statusMessage = localized ?? error.localizedDescription
        }

        isLoading = false
    }
}

private enum Provider: String, CaseIterable, Identifiable {
    case apple
    case google
    case microsoft

    var id: String { rawValue }

    var buttonTitle: String {
        switch self {
        case .apple: return "Sign in with Apple"
        case .google: return "Sign in with Google"
        case .microsoft: return "Sign in with Microsoft"
        }
    }

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .microsoft: return "Microsoft"
        }
    }

    var fakeToken: String {
        switch self {
        case .apple: return "apple_fake_token"
        case .google: return "google_fake_token"
        case .microsoft: return "microsoft_fake_token"
        }
    }

    var tint: Color {
        switch self {
        case .apple:
            return Color(.sRGB, red: 0.12, green: 0.12, blue: 0.12, opacity: 1.0)
        case .google:
            return Color(.sRGB, red: 0.22, green: 0.53, blue: 0.96, opacity: 1.0)
        case .microsoft:
            return Color(.sRGB, red: 0.11, green: 0.47, blue: 0.87, opacity: 1.0)
        }
    }
}

#Preview {
    LoginView()
}
