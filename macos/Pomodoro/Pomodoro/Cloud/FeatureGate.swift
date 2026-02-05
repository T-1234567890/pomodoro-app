import Foundation
import Combine

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

    static let shared = FeatureGate()

    private init() {}

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

    // MARK: - Networking

    /// Placeholder: set tier based on presence of session until backend is wired.
    @MainActor
    func refreshTier() async {
        if AuthStore.shared.loadSession() != nil {
            tier = .developer
        } else {
            tier = .free
        }
    }
}
