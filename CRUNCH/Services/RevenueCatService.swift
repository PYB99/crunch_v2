import Foundation
import RevenueCat
import OSLog

private let logger = Logger(subsystem: "com.pyb99.crunch", category: "RevenueCatService")

@Observable
final class RevenueCatService {
    static let shared = RevenueCatService()

    private(set) var isPro: Bool = false

    // Accessing Purchases.shared before configure() traps (SIGTRAP). configure()
    // no-ops when the public key is absent (dev/sim without secrets), so every
    // Purchases.shared access below must be gated on this flag.
    private(set) var isConfigured = false

    private init() {}

    func configure() {
        guard !Constants.revenueCatPublicKey.isEmpty else { return }
        Purchases.configure(withAPIKey: Constants.revenueCatPublicKey)
        Purchases.logLevel = .error
        isConfigured = true
    }

    func identifyUser(clerkUserId: String) {
        guard isConfigured else { return }
        Purchases.shared.logIn(clerkUserId) { [weak self] _, _, _ in
            Task { await self?.refreshEntitlements() }
        }
    }

    func refreshEntitlements() async {
        guard isConfigured else { return }
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
        guard isConfigured else { return }
        Purchases.shared.logOut { _, _ in }
    }

    // MARK: - Purchase (onboarding paywall — Phase 5)

    // Current offering's packages, or [] when RevenueCat isn't configured / offerings
    // are unavailable (dev without sandbox) so the paywall can degrade gracefully.
    func currentPackages() async -> [Package] {
        guard isConfigured else { return [] }
        return (try? await Purchases.shared.offerings())?.current?.availablePackages ?? []
    }

    // Returns true when the purchase completed with the `pro` entitlement active.
    // User-cancel and errors both return false (the caller stays on the paywall).
    func purchase(_ package: Package) async -> Bool {
        guard isConfigured else { return false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            await refreshEntitlements()
            return result.customerInfo.entitlements[Constants.revenueCatEntitlementID]?.isActive == true
        } catch {
            logger.error("purchase failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
