import Foundation
import RevenueCat
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "RevenueCatService")

@Observable
final class RevenueCatService {
    static let shared = RevenueCatService()

    private(set) var isPro: Bool = false

    private init() {}

    func configure() {
        guard !Constants.revenueCatPublicKey.isEmpty else { return }
        Purchases.configure(withAPIKey: Constants.revenueCatPublicKey)
        Purchases.logLevel = .error
    }

    func identifyUser(clerkUserId: String) {
        Purchases.shared.logIn(clerkUserId) { [weak self] _, _, _ in
            Task { await self?.refreshEntitlements() }
        }
    }

    func refreshEntitlements() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.isPro = info.entitlements[Constants.revenueCatEntitlementID]?.isActive == true
            }
        } catch {
            logger.error("RevenueCat entitlement check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resetUser() {
        Purchases.shared.logOut { _, _ in }
    }
}
