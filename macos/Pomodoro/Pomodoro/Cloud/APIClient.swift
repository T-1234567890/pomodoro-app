import Foundation
import FirebaseAuth
import FirebaseCore

final class APIClient {
    enum APIError: LocalizedError {
        case invalidEndpoint
        case authRequired
        case missingToken

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: return "Unable to form endpoint URL."
            case .authRequired: return "Authentication is required."
            case .missingToken: return "Missing Firebase ID token."
            }
        }
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    static let shared = APIClient()

    private let auth: Auth

    private init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        body: Data? = nil
    ) async throws -> URLRequest {
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

        let token = try await fetchIDToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func fetchIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = auth.currentUser else {
            throw APIError.authRequired
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forceRefresh) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token, !token.isEmpty else {
                    continuation.resume(throwing: APIError.missingToken)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }

    private static var baseURL: URL {
        if let plistURL = Bundle.main.infoDictionary?["POMODORO_CLOUD_BASE_URL"] as? String,
           let url = URL(string: plistURL) {
            return url
        }
        return URL(string: "https://api.pomodoroapp.xyz")!
    }
}

/// Typed client for calling the Firebase HTTPS function `aiProxy`.
///
/// Example usage:
/// ```swift
/// let client = AIProxyClient()
/// let payload = AIProxyClient.PromptRequest(
///     prompt: "Summarize my focus sessions for today."
/// )
/// let response: AIProxyClient.ProxyResponse = try await client.sendPrompt(payload)
/// print(response.outputText ?? "")
/// ```
final class AIProxyClient {
    struct PromptRequest: Encodable {
        let prompt: String
        let model: String?
        let temperature: Double?
        let maxOutputTokens: Int?
        let metadata: [String: String]?

        init(
            prompt: String,
            model: String? = nil,
            temperature: Double? = nil,
            maxOutputTokens: Int? = nil,
            metadata: [String: String]? = nil
        ) {
            self.prompt = prompt
            self.model = model
            self.temperature = temperature
            self.maxOutputTokens = maxOutputTokens
            self.metadata = metadata
        }

        enum CodingKeys: String, CodingKey {
            case prompt
            case model
            case temperature
            case maxOutputTokens = "max_output_tokens"
            case metadata
        }
    }

    /// Default response type for common aiProxy JSON payloads.
    struct ProxyResponse: Decodable {
        let text: String?
        let output: String?
        let result: String?

        var outputText: String? {
            text ?? output ?? result
        }
    }

    enum AIProxyError: LocalizedError {
        case invalidEndpoint
        case unauthorized
        case forbidden(message: String?)
        case quotaExceeded(message: String?)
        case decodingFailed(Swift.Error)
        case invalidResponse
        case network(Swift.Error)
        case http(statusCode: Int, message: String?)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Unable to form aiProxy endpoint URL."
            case .unauthorized:
                return "Authentication required (401)."
            case .forbidden(let message):
                return message ?? "Access forbidden (403)."
            case .quotaExceeded(let message):
                return message ?? "Quota exceeded (429)."
            case .decodingFailed:
                return "Failed to decode aiProxy response."
            case .invalidResponse:
                return "Invalid response from aiProxy."
            case .network(let error):
                return error.localizedDescription
            case .http(let statusCode, let message):
                return message ?? "aiProxy request failed with status \(statusCode)."
            }
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct InnerError: Decodable {
            let message: String?
            let status: String?
            let code: Int?
        }

        let error: InnerError?
        let message: String?
    }

    private let session: URLSession
    private let region: String

    init(
        session: URLSession = .shared,
        region: String? = nil
    ) {
        self.session = session
        if let region {
            self.region = region
        } else if let configured = Bundle.main.infoDictionary?["POMODORO_CLOUD_FUNCTION_REGION"] as? String,
                  !configured.isEmpty {
            self.region = configured
        } else {
            self.region = "us-central1"
        }
    }

    func sendPrompt<Response: Decodable>(_ requestBody: PromptRequest, decodeAs: Response.Type = Response.self) async throws -> Response {
        try await send(requestBody, decodeAs: decodeAs)
    }

    func send<Body: Encodable, Response: Decodable>(_ body: Body, decodeAs: Response.Type = Response.self) async throws -> Response {
        let token = try await AuthViewModel.shared.getValidIDToken()
        let endpoint = try resolveEndpointURL()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw AIProxyError.network(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AIProxyError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw AIProxyError.decodingFailed(error)
            }
        case 401:
            throw AIProxyError.unauthorized
        case 403:
            throw AIProxyError.forbidden(message: extractErrorMessage(from: data))
        case 429:
            throw AIProxyError.quotaExceeded(message: extractErrorMessage(from: data))
        default:
            throw AIProxyError.http(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data)
            )
        }
    }

    private func resolveEndpointURL() throws -> URL {
        if let explicit = Bundle.main.infoDictionary?["POMODORO_AI_PROXY_URL"] as? String,
           let url = URL(string: explicit), !explicit.isEmpty {
            return url
        }

        guard let projectID = FirebaseApp.app()?.options.projectID,
              !projectID.isEmpty else {
            throw AIProxyError.invalidEndpoint
        }

        guard let url = URL(string: "https://\(region)-\(projectID).cloudfunctions.net/aiProxy") else {
            throw AIProxyError.invalidEndpoint
        }
        return url
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let decoded = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return decoded.error?.message ?? decoded.message
        }
        if let raw = String(data: data, encoding: .utf8),
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw
        }
        return nil
    }
}
