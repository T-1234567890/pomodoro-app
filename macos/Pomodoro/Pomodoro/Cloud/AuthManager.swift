import AppKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import ObjectiveC.runtime

@MainActor
final class AuthManager {
    static let shared = AuthManager()

    private init() {}

    func signInWithGoogle() async throws -> String {
        guard FirebaseApp.app() != nil else {
            throw AuthManagerError.firebaseNotConfigured
        }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            throw AuthManagerError.missingGoogleClientID
        }
        guard let presentingWindow = presentingWindow() else {
            throw AuthManagerError.missingPresentingWindow
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("[Auth] Starting Google sign-in")

        do {
            let googleResult: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let result else {
                        continuation.resume(throwing: AuthManagerError.missingResult)
                        return
                    }
                    continuation.resume(returning: result)
                }
            }
            guard
                let idToken = googleResult.user.idToken?.tokenString,
                !idToken.isEmpty
            else {
                throw AuthManagerError.missingGoogleIDToken
            }

            let accessToken = googleResult.user.accessToken.tokenString
            guard !accessToken.isEmpty else {
                throw AuthManagerError.missingGoogleAccessToken
            }

            print("[Auth] Google token retrieval succeeded")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let authResult = try await signIn(with: credential)
            print("[Auth] Google sign-in succeeded for uid: \(authResult.user.uid)")
            return authResult.user.uid
        } catch {
            log(error, prefix: "[Auth] Google sign-in failed")
            throw error
        }
    }

    func signInWithGitHub() async throws -> String {
        guard FirebaseApp.app() != nil else {
            throw AuthManagerError.firebaseNotConfigured
        }

        let provider = OAuthProvider(providerID: "github.com")
        provider.scopes = ["user:email"]
        print("[Auth] Starting GitHub OAuth")

        do {
            let credential = try await githubCredential(from: provider)
            print("[Auth] OAuth returned credential")
            print("[Auth] Signing into Firebase")
            let authResult = try await signIn(with: credential)
            print("[Auth] GitHub sign-in succeeded for uid: \(authResult.user.uid)")
            return authResult.user.uid
        } catch {
            log(error, prefix: "[Auth] GitHub sign-in failed")
            throw error
        }
    }

    func signInWithGithub() async throws -> String {
        try await signInWithGitHub()
    }

    func signOut() {
        guard FirebaseApp.app() != nil else { return }

        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            print("[Auth] Signed out")
        } catch {
            log(error, prefix: "[Auth] Sign-out failed")
        }
    }

    func currentUser() -> User? {
        Auth.auth().currentUser
    }

    private func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    print("[Auth] Firebase sign-in error: \((error as NSError).localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthManagerError.missingResult)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func githubCredential(from provider: OAuthProvider) async throws -> AuthCredential {
        let selector = NSSelectorFromString("getCredentialWith:completion:")
        guard let method = class_getInstanceMethod(OAuthProvider.self, selector) else {
            throw AuthManagerError.missingResult
        }

        typealias CredentialBlock = @convention(block) (AuthCredential?, Error?) -> Void
        typealias CredentialFunction = @convention(c) (AnyObject, Selector, AnyObject?, CredentialBlock?) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: CredentialFunction.self)

        return try await withCheckedThrowingContinuation { continuation in
            let completion: CredentialBlock = { credential, error in
                if let error {
                    print("[Auth] GitHub auth error: \((error as NSError).localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let credential else {
                    print("[Auth] Authentication did not return a result")
                    continuation.resume(throwing: AuthManagerError.missingResult)
                    return
                }
                continuation.resume(returning: credential)
            }
            function(provider, selector, nil, completion)
        }
    }

    private func signIn(with provider: OAuthProvider) async throws -> AuthDataResult {
        let auth = Auth.auth()
        let selector = NSSelectorFromString("signInWithProvider:UIDelegate:completion:")
        guard let method = class_getInstanceMethod(Auth.self, selector) else {
            throw AuthManagerError.missingResult
        }

        typealias SignInBlock = @convention(block) (AuthDataResult?, Error?) -> Void
        typealias SignInFunction = @convention(c) (AnyObject, Selector, AnyObject, AnyObject?, SignInBlock?) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: SignInFunction.self)

        return try await withCheckedThrowingContinuation { continuation in
            let completion: SignInBlock = { result, error in
                if let result {
                    continuation.resume(returning: result)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(throwing: AuthManagerError.missingResult)
            }
            function(auth, selector, provider, nil, completion)
        }
    }

    private func presentingWindow() -> NSWindow? {
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        if let mainWindow = NSApplication.shared.mainWindow {
            return mainWindow
        }
        return NSApplication.shared.windows.first(where: { $0.canBecomeMain })
    }

    private func log(_ error: Error, prefix: String) {
        let nsError = error as NSError
        print("\(prefix): \(nsError.localizedDescription) [\(nsError.domain):\(nsError.code)]")
    }
}

enum AuthManagerError: LocalizedError {
    case firebaseNotConfigured
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingGoogleAccessToken
    case missingPresentingWindow
    case missingResult

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured."
        case .missingGoogleClientID:
            return "Missing Google OAuth client ID in Firebase configuration."
        case .missingGoogleIDToken:
            return "Google Sign-In did not return an ID token."
        case .missingGoogleAccessToken:
            return "Google Sign-In did not return an access token."
        case .missingPresentingWindow:
            return "No active macOS window is available to present the login flow."
        case .missingResult:
            return "Authentication did not return a result."
        }
    }
}
