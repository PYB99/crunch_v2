import Foundation

// nonisolated so these immutable static constants can be read from any actor
// (e.g. the SupabaseService actor). Without this, SWIFT_DEFAULT_ACTOR_ISOLATION
// = MainActor makes every member MainActor-isolated, which errors under Swift 6.
nonisolated enum Constants {
    // MARK: - Supabase (public — safe to commit)
    static let supabaseURL = "https://ryswtwcgzhmkmgzcklyx.supabase.co"

    // MARK: - Edge Function URLs
    // Most function calls build their URL inline; the destructive
    // delete-account endpoint is named here so its one call site is explicit.
    static let deleteAccountFunctionURL = "\(supabaseURL)/functions/v1/delete-account"

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

    // MARK: - Diet Layer (master-spec §9.2)
    // Coach copy for the low-carb/keto conflict flag. The engine raises
    // DietLayer.dietCarbConflictFlag rather than overriding carbs; the Coach opens
    // this conversation. Not reachable from onboarding (omni/veg/vegan/pesc only),
    // but honoured for imported/edited profiles.
    static let dietCarbConflictCoachCopy =
        "Heads up — you've told us you eat low-carb, but the fueling targets for your " +
        "race lean heavily on carbohydrate, which is what the research supports for " +
        "race-pace performance. Want to talk through how to reconcile the two?"

    // MARK: - Validation Limits
    static let maxMealDescriptionLength = 500
    static let maxCoachInputLength      = 2_000
    static let maxRaceNameLength        = 100
    static let coachHistoryLimit        = 20

    // MARK: - Timeouts / Rates
    static let apiTimeoutSeconds: TimeInterval = 30
    static let coachSendCooldownSeconds: TimeInterval = 2
}
