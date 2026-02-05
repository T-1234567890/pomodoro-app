import Foundation

/// Builds authenticated requests; transport will be added when backend endpoints are ready.
final class APIClient {
    enum APIError: LocalizedError {
        case invalidEndpoint
        case authRequired

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: return "Unable to form endpoint URL."
            case .authRequired: return "Authentication is required."
            }
        }
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    static let shared = APIClient()

    private let authManager: AuthManager

    init(authManager: AuthManager = .shared) {
        self.authManager = authManager
    }

    func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: Self.baseURL) else {
            throw APIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        guard let token = authManager.session?.accessToken else {
            throw APIError.authRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    private static var baseURL: URL {
        if let plistURL = Bundle.main.infoDictionary?["POMODORO_CLOUD_BASE_URL"] as? String,
           let url = URL(string: plistURL) {
            return url
        }
        return URL(string: "https://api.pomodoroapp.xyz")!
    }
}
