import Foundation
import Combine
import FirebaseAuth

/// Entitlement-aware feature gating for cloud-powered capabilities.
final class FeatureGate: ObservableObject {
    enum Tier: String, Decodable {
        case free
        case beta
        case plus
        case pro
        case expired
        case developer
    }

    @Published private(set) var tier: Tier = .free
    @Published private(set) var deepSeekRemainingTokens: Int?
    @Published private(set) var deepSeekMonthlyLimit: Int?
    @Published private(set) var geminiFlash3RemainingTokens: Int?
    @Published private(set) var geminiFlash3MonthlyLimit: Int?
    @Published private(set) var allowanceResetAt: Date?
    @Published private(set) var isRefreshingAllowance = false
    @Published private(set) var allowanceErrorMessage: String?

    static let shared = FeatureGate()

    private var authListener: AuthStateDidChangeListenerHandle?
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
        listenForAuthChanges()
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    // MARK: - Permissions

    var canUseCloudProxyAI: Bool {
        switch tier {
        case .plus, .pro, .beta, .developer:
            return true
        default:
            return false
        }
    }

    var canUseNotesProFeatures: Bool {
        switch tier {
        case .pro, .developer:
            return true
        default:
            return false
        }
    }

    var canUseSharePrivateSocial: Bool {
        switch tier {
        case .plus, .pro, .beta, .developer:
            return true
        default:
            return false
        }
    }

    var isExpired: Bool {
        tier == .expired
    }

    var hasAnyQuotaData: Bool {
        deepSeekRemainingTokens != nil || geminiFlash3RemainingTokens != nil
    }

    var isAIQuotaExhausted: Bool {
        let trackedValues = [deepSeekRemainingTokens, geminiFlash3RemainingTokens].compactMap { $0 }
        guard !trackedValues.isEmpty else { return false }
        return trackedValues.allSatisfy { $0 <= 0 }
    }

    var canTriggerAIAction: Bool {
        canUseCloudProxyAI && !isAIQuotaExhausted
    }

    var aiActionDisabledReason: String? {
        if !canUseCloudProxyAI {
            return "Your current tier does not include AI access."
        }
        if isAIQuotaExhausted {
            if let resetText = allowanceResetAt.map(Self.resetFormatter.string(from:)) {
                return "AI quota exhausted. It will refresh on \(resetText)."
            }
            return "AI quota exhausted for this cycle."
        }
        return nil
    }

    // MARK: - Networking

    @MainActor
    func refreshTier() async {
        await refreshAllowance()
    }

    @MainActor
    func refreshAllowance() async {
        guard AuthViewModel.shared.isAuthenticated else {
            resetToSignedOutState()
            return
        }

        isRefreshingAllowance = true
        allowanceErrorMessage = nil
        defer { isRefreshingAllowance = false }

        do {
            let request = try await APIClient.shared.makeRequest(
                path: Self.allowancePath,
                method: .get
            )
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GateError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                let payload = try decodeAllowancePayload(data: data)
                apply(payload: payload)
            case 401:
                resetToSignedOutState()
                allowanceErrorMessage = "Session expired. Please sign in again."
            case 403:
                allowanceErrorMessage = "Your account cannot access allowance data."
            default:
                throw GateError.httpStatus(httpResponse.statusCode)
            }
        } catch {
            allowanceErrorMessage = error.localizedDescription
        }
    }

    private func listenForAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if user == nil {
                    self.resetToSignedOutState()
                } else {
                    await self.refreshAllowance()
                }
            }
        }
    }

    @MainActor
    private func resetToSignedOutState() {
        tier = .free
        deepSeekRemainingTokens = nil
        deepSeekMonthlyLimit = nil
        geminiFlash3RemainingTokens = nil
        geminiFlash3MonthlyLimit = nil
        allowanceResetAt = nil
    }

    @MainActor
    private func apply(payload: AllowancePayload) {
        tier = payload.tier ?? .free
        deepSeekRemainingTokens = payload.deepSeekRemainingTokens
        deepSeekMonthlyLimit = payload.deepSeekMonthlyLimit
        geminiFlash3RemainingTokens = payload.geminiFlash3RemainingTokens
        geminiFlash3MonthlyLimit = payload.geminiFlash3MonthlyLimit
        allowanceResetAt = payload.resetAt
    }

    private func decodeAllowancePayload(data: Data) throws -> AllowancePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(AllowanceResponse.self, from: data) {
            return decoded.payload
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            throw GateError.decodingFailed
        }
        return AllowancePayload(json: json)
    }

    private enum GateError: LocalizedError {
        case invalidResponse
        case decodingFailed
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid allowance response."
            case .decodingFailed:
                return "Failed to decode allowance payload."
            case .httpStatus(let status):
                return "Allowance request failed with status \(status)."
            }
        }
    }

    private struct AllowanceResponse: Decodable {
        let tier: Tier?
        let deepseek: ProviderQuota?
        let deepSeek: ProviderQuota?
        let geminiFlash3: ProviderQuota?
        let gemini_flash_3: ProviderQuota?
        let allowances: [String: ProviderQuota]?
        let quotas: [String: ProviderQuota]?
        let deepseekRemaining: Int?
        let deepseekLimit: Int?
        let geminiFlash3Remaining: Int?
        let geminiFlash3Limit: Int?
        let resetAt: Date?
        let reset_at: Date?

        var payload: AllowancePayload {
            let deepSeekQuota = deepseek ?? deepSeek ?? allowances?["deepseek"] ?? quotas?["deepseek"]
            let geminiQuota = geminiFlash3
                ?? gemini_flash_3
                ?? allowances?["geminiFlash3"]
                ?? allowances?["gemini_flash_3"]
                ?? quotas?["geminiFlash3"]
                ?? quotas?["gemini_flash_3"]

            return AllowancePayload(
                tier: tier,
                deepSeekRemainingTokens: deepSeekQuota?.remaining ?? deepseekRemaining,
                deepSeekMonthlyLimit: deepSeekQuota?.limit ?? deepseekLimit,
                geminiFlash3RemainingTokens: geminiQuota?.remaining ?? geminiFlash3Remaining,
                geminiFlash3MonthlyLimit: geminiQuota?.limit ?? geminiFlash3Limit,
                resetAt: resetAt ?? reset_at
            )
        }
    }

    private struct ProviderQuota: Decodable {
        let remaining: Int?
        let limit: Int?
    }

    private struct AllowancePayload {
        let tier: Tier?
        let deepSeekRemainingTokens: Int?
        let deepSeekMonthlyLimit: Int?
        let geminiFlash3RemainingTokens: Int?
        let geminiFlash3MonthlyLimit: Int?
        let resetAt: Date?

        init(
            tier: Tier?,
            deepSeekRemainingTokens: Int?,
            deepSeekMonthlyLimit: Int?,
            geminiFlash3RemainingTokens: Int?,
            geminiFlash3MonthlyLimit: Int?,
            resetAt: Date?
        ) {
            self.tier = tier
            self.deepSeekRemainingTokens = deepSeekRemainingTokens
            self.deepSeekMonthlyLimit = deepSeekMonthlyLimit
            self.geminiFlash3RemainingTokens = geminiFlash3RemainingTokens
            self.geminiFlash3MonthlyLimit = geminiFlash3MonthlyLimit
            self.resetAt = resetAt
        }

        init(json: [String: Any]) {
            let rawTier = (json["tier"] as? String)?.lowercased()
            self.tier = rawTier.flatMap(Tier.init(rawValue:))

            let deepseek = (json["deepseek"] as? [String: Any]) ?? (json["deepSeek"] as? [String: Any])
            let gemini = (json["geminiFlash3"] as? [String: Any]) ?? (json["gemini_flash_3"] as? [String: Any])

            self.deepSeekRemainingTokens = deepseek?["remaining"] as? Int ?? json["deepseekRemaining"] as? Int
            self.deepSeekMonthlyLimit = deepseek?["limit"] as? Int ?? json["deepseekLimit"] as? Int
            self.geminiFlash3RemainingTokens = gemini?["remaining"] as? Int ?? json["geminiFlash3Remaining"] as? Int
            self.geminiFlash3MonthlyLimit = gemini?["limit"] as? Int ?? json["geminiFlash3Limit"] as? Int

            if let reset = json["resetAt"] as? String {
                self.resetAt = Self.parseDate(reset)
            } else if let reset = json["reset_at"] as? String {
                self.resetAt = Self.parseDate(reset)
            } else {
                self.resetAt = nil
            }
        }

        private static func parseDate(_ value: String) -> Date? {
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }
            return nil
        }
    }

    private static var allowancePath: String {
        if let configured = Bundle.main.infoDictionary?["POMODORO_GET_ALLOWANCE_PATH"] as? String,
           !configured.isEmpty {
            return configured
        }
        return "/getAllowance"
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    static func formatTokenCount(_ value: Int?) -> String {
        guard let value else { return "—" }
        return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    static func tierDisplayName(_ tier: Tier) -> String {
        switch tier {
        case .free: return "Free"
        case .beta: return "Beta"
        case .plus: return "Plus"
        case .pro: return "Pro"
        case .expired: return "Expired"
        case .developer: return "Developer"
        }
    }
}
