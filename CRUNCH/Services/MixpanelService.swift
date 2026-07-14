import Foundation
import Mixpanel

enum MixpanelService {

    static func configure() {
        Mixpanel.initialize(token: Constants.mixpanelToken, trackAutomaticEvents: false)
    }

    static func identify(clerkUserId: String) {
        Mixpanel.mainInstance().identify(distinctId: clerkUserId)
    }

    static func reset() {
        Mixpanel.mainInstance().reset()
    }

    static func track(_ event: AnalyticsEvent) {
        Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
    }
}

// MARK: - Events

enum AnalyticsEvent {
    case onboardingStarted
    case onboardingScreenViewed(number: Int, name: String)
    case onboardingCompleted(raceType: String, trainingLevel: String)
    case mealAdded(mealTime: String)
    case activityAdded(activityType: String)
    case coachMessageSent(isPostRun: Bool)
    case subscriptionStarted(productId: String, isTrial: Bool)
    case stravaConnected
    case runnaConnected

    var name: String {
        switch self {
        case .onboardingStarted:                    return "onboarding_started"
        case .onboardingScreenViewed:               return "onboarding_screen_viewed"
        case .onboardingCompleted:                  return "onboarding_completed"
        case .mealAdded:                            return "meal_added"
        case .activityAdded:                        return "activity_added"
        case .coachMessageSent:                     return "coach_message_sent"
        case .subscriptionStarted:                  return "subscription_started"
        case .stravaConnected:                      return "strava_connected"
        case .runnaConnected:                       return "runna_connected"
        }
    }

    var properties: [String: MixpanelType]? {
        switch self {
        case .onboardingStarted, .stravaConnected, .runnaConnected:
            return nil
        case let .onboardingScreenViewed(number, name):
            return ["screen_number": number, "screen_name": name]
        case let .onboardingCompleted(raceType, trainingLevel):
            return ["race_type": raceType, "training_level": trainingLevel]
        case let .mealAdded(mealTime):
            return ["meal_time": mealTime]
        case let .activityAdded(activityType):
            return ["activity_type": activityType]
        case let .coachMessageSent(isPostRun):
            return ["is_post_run": isPostRun]
        case let .subscriptionStarted(productId, isTrial):
            return ["product_id": productId, "is_trial": isTrial]
        }
    }
}
