import AppKit
import Foundation
import Combine
#if canImport(GoogleSignInSwift)
import GoogleSignInSwift
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Coordinates authentication and session persistence.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var session: AuthSession?
    @Published private(set) var signingIn: Bool = false

    private let authStore: AuthStore
    #if canImport(GoogleSignIn)
    private let configuration: GIDConfiguration?
    #endif

    private init(authStore: AuthStore = .shared) {
        self.authStore = authStore
        #if canImport(GoogleSignIn)
        if CloudAuthEnabled {
            self.configuration = GIDConfiguration(clientID: "408122766816-ahi7h5e0nma00dv7o1vutrbacvt34c10.apps.googleusercontent.com")
            GIDSignIn.sharedInstance.configuration = configuration
        } else {
            self.configuration = nil
        }
        #endif
        self.session = authStore.loadSession()
    }

    var isAuthenticated: Bool { session != nil }

    /// Launches Google OAuth and stores the resulting session.
    func signIn(presentingWindow: NSWindow? = nil) async throws -> AuthSession {
        guard CloudAuthEnabled else {
            throw SignInError.disabled
        }
        #if canImport(GoogleSignIn)
        guard signingIn == false else {
            print("[AuthManager] signIn skipped: already signing in")
            throw SignInError.inProgress
        }
        signingIn = true
        defer { signingIn = false }

        NSApplication.shared.activate(ignoringOtherApps: true)

        let window = presentingWindow
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first(where: { $0.isVisible })
            ?? NSApplication.shared.windows.first

        print("[AuthManager] Sign in started")
        print("[AuthManager] Window:", String(describing: window))
        print("[AuthManager] App windows:", NSApplication.shared.windows)

        guard let window else {
            print("❌ No key window available")
            throw SignInError.missingWindow
        }
        if window.isVisible == false {
            print("[AuthManager] Bringing window to front for Google sign-in.")
            window.makeKeyAndOrderFront(nil)
        }

        guard let config = GIDSignIn.sharedInstance.configuration ?? Optional(configuration) else {
            print("[AuthManager] Sign-in aborted: missing GIDConfiguration.")
            throw SignInError.sdkUnavailable
        }
        GIDSignIn.sharedInstance.configuration = config

        print("[AuthManager] Starting Google sign-in… window=\(window), config=\(config)")

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
            print("[AuthManager] Sign in callback received:", result)

            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                print("[AuthManager] Sign-in failed: missing user/idToken")
                throw SignInError.missingIDToken
            }

            let access = user.accessToken
            let authSession = AuthSession(
                userId: user.userID ?? UUID().uuidString,
                email: user.profile?.email ?? "",
                idToken: idToken,
                accessToken: access.tokenString,
                refreshToken: nil,
                expirationDate: access.expirationDate ?? Date().addingTimeInterval(3600)
            )

            print("[AuthManager] Google sign-in success: email=\(authSession.email), expires=\(authSession.expirationDate)")
            DispatchQueue.main.async { [weak self] in
                self?.authStore.save(session: authSession)
                self?.session = authSession
            }
            return authSession
        } catch {
            print("[AuthManager] Google sign-in failed:", error.localizedDescription)
            DispatchQueue.main.async { [weak self] in
                self?.session = self?.authStore.loadSession()
            }
            throw SignInError.underlying(error)
        }
        #else
        throw SignInError.sdkUnavailable
        #endif
    }

    @MainActor
    func signOut() {
        #if canImport(GoogleSignIn)
        if CloudAuthEnabled {
            GIDSignIn.sharedInstance.signOut()
        }
        #endif
        authStore.clearSession()
        session = nil
        print("[AuthManager] Signed out")
    }

    @MainActor
    func logout() {
        signOut()
    }

    enum SignInError: LocalizedError {
        case missingWindow
        case missingIDToken
        case sdkUnavailable
        case disabled
        case inProgress
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .missingWindow:
                return "No active window to present Google Sign-In."
            case .missingIDToken:
                return "Google sign-in succeeded but no ID token was returned."
            case .sdkUnavailable:
                return "GoogleSignIn SDK is unavailable on this build."
            case .disabled:
                return "Google sign-in is temporarily disabled."
            case .inProgress:
                return "A sign-in operation is already in progress."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }
}
