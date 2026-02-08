import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import ObjectiveC.runtime

final class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()

    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var auth: Auth?

    private init() {
        if FirebaseApp.app() != nil {
            let auth = Auth.auth()
            self.auth = auth
            currentUser = auth.currentUser
        } else {
            currentUser = nil
        }
    }

    deinit {
        if let authStateListener, let auth {
            auth.removeStateDidChangeListener(authStateListener)
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    var isAuthenticated: Bool {
        isLoggedIn
    }

    var isSignedIn: Bool {
        isLoggedIn
    }

    var user: User? {
        currentUser
    }

    var currentUserEmail: String {
        currentUser?.email ?? ""
    }

    func startListeningIfNeeded() {
        guard authStateListener == nil else { return }
        guard FirebaseApp.app() != nil else { return }
        guard let auth = try? currentAuth() else { return }
        currentUser = auth.currentUser
        listen(using: auth)
    }

    private func listen(using auth: Auth) {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
            }
        }
    }

    @MainActor
    func signInWithGoogle() async throws {
        try await performAuthFlow {
            let provider = OAuthProvider(providerID: "google.com")
            provider.customParameters = ["prompt": "select_account"]
            _ = try await signIn(with: provider)
        }
    }

    @MainActor
    func signUpWithEmail(email: String, password: String) async throws {
        try await performAuthFlow {
            let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sanitizedEmail.isEmpty else {
                throw AuthViewModelError.invalidEmail
            }
            guard !password.isEmpty else {
                throw AuthViewModelError.invalidPassword
            }
            _ = try await createUser(email: sanitizedEmail, password: password)
        }
    }

    @MainActor
    func signInWithEmail(email: String, password: String) async throws {
        try await performAuthFlow {
            let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sanitizedEmail.isEmpty else {
                throw AuthViewModelError.invalidEmail
            }
            guard !password.isEmpty else {
                throw AuthViewModelError.invalidPassword
            }
            _ = try await signIn(email: sanitizedEmail, password: password)
        }
    }

    @MainActor
    func getValidIDToken() async throws -> String {
        startListeningIfNeeded()
        let auth = try currentAuth()
        guard let user = auth.currentUser else {
            throw AuthViewModelError.notAuthenticated
        }

        do {
            let tokenResult = try await getIDTokenResult(for: user, forceRefresh: false)
            let expirationDate = tokenResult.expirationDate
            if expirationDate.timeIntervalSinceNow > 60 {
                return tokenResult.token
            }

            return try await getIDToken(for: user, forceRefresh: true)
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               nsError.code == AuthErrorCode.userTokenExpired.rawValue {
                return try await getIDToken(for: user, forceRefresh: true)
            }
            throw error
        }
    }

    func signOut() {
        guard let auth = try? currentAuth() else {
            currentUser = nil
            errorMessage = nil
            return
        }
        do {
            try auth.signOut()
            currentUser = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func performAuthFlow(_ operation: () async throws -> Void) async throws {
        startListeningIfNeeded()
        let auth = try currentAuth()

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
            currentUser = auth.currentUser
            errorMessage = nil
        } catch {
            errorMessage = (error as NSError).localizedDescription
            throw error
        }
    }

    private func signIn(with provider: OAuthProvider) async throws -> AuthDataResult {
        let auth = try currentAuth()
        let selector = NSSelectorFromString("signInWithProvider:UIDelegate:completion:")
        guard let method = class_getInstanceMethod(Auth.self, selector) else {
            throw AuthViewModelError.missingResult
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
                continuation.resume(throwing: AuthViewModelError.missingResult)
            }
            function(auth, selector, provider, nil, completion)
        }
    }

    private func createUser(email: String, password: String) async throws -> AuthDataResult {
        let auth = try currentAuth()
        return try await withCheckedThrowingContinuation { continuation in
            auth.createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthViewModelError.missingResult)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func signIn(email: String, password: String) async throws -> AuthDataResult {
        let auth = try currentAuth()
        return try await withCheckedThrowingContinuation { continuation in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthViewModelError.missingResult)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func currentAuth() throws -> Auth {
        guard FirebaseApp.app() != nil else {
            throw AuthViewModelError.firebaseNotConfigured
        }
        if let auth {
            return auth
        }
        let initializedAuth = Auth.auth()
        auth = initializedAuth
        return initializedAuth
    }

    private func getIDToken(for user: User, forceRefresh: Bool) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forceRefresh) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token, !token.isEmpty else {
                    continuation.resume(throwing: AuthViewModelError.missingToken)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }

    private func getIDTokenResult(for user: User, forceRefresh: Bool) async throws -> AuthTokenResult {
        try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenResult(forcingRefresh: forceRefresh) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthViewModelError.missingToken)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    enum AuthViewModelError: LocalizedError {
        case firebaseNotConfigured
        case missingResult
        case invalidEmail
        case invalidPassword
        case notAuthenticated
        case missingToken

        var errorDescription: String? {
            switch self {
            case .firebaseNotConfigured:
                return "Firebase is not configured."
            case .missingResult:
                return "Sign in failed."
            case .invalidEmail:
                return "Please enter a valid email."
            case .invalidPassword:
                return "Please enter a valid password."
            case .notAuthenticated:
                return "Authentication is required."
            case .missingToken:
                return "Missing Firebase ID token."
            }
        }
    }
}
