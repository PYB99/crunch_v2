import Foundation

// nonisolated so these immutable static constants can be read from any actor
// (e.g. the SupabaseService actor). Without this, SWIFT_DEFAULT_ACTOR_ISOLATION
// = MainActor makes every member MainActor-isolated, which errors under Swift 6.
nonisolated enum Constants {
    // MARK: - Supabase (public — safe to commit)
    static let supabaseURL = "https://ryswtwcgzhmkmgzcklyx.supabase.co"

    // MARK: - Strava
    static let stravaClientID   = "251794"
    static let stravaRedirectURI = "crunch://strava-callback"
    static let stravaAuthorizeURL = "https://www.strava.com/oauth/mobile/authorize"

    // MARK: - RevenueCat
    static let revenueCatEntitlementID  = "pro"
    static let revenueCatMonthlyProduct = "com.pyb99.crunch.monthly"
    static let revenueCatAnnualProduct  = "com.pyb99.crunch.annual"

    // MARK: - Mixpanel (public token)
    static let mixpanelToken = "6bfd597733d1ff2d47ce3b622cb2dc72"

    // MARK: - Secrets (injected from Info.plist via Secrets.xcconfig)
    static let supabaseAnonKey: String =
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let clerkPublishableKey: String =
        Bundle.main.infoDictionary?["CLERK_PUBLISHABLE_KEY"] as? String ?? ""
    static let revenueCatPublicKey: String =
        Bundle.main.infoDictionary?["REVENUECAT_PUBLIC_KEY"] as? String ?? ""

    // MARK: - Validation Limits
    static let maxMealDescriptionLength = 500
    static let maxCoachInputLength      = 2_000
    static let maxRaceNameLength        = 100
    static let coachHistoryLimit        = 20

    // MARK: - Timeouts / Rates
    static let apiTimeoutSeconds: TimeInterval = 30
    static let coachSendCooldownSeconds: TimeInterval = 2
}
