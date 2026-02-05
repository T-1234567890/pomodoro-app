import Foundation

/// Represents an authenticated user session.
struct AuthSession: Codable, Equatable {
    let userId: String
    let email: String
    let idToken: String?
    let accessToken: String
    let refreshToken: String?
    let expirationDate: Date
}
