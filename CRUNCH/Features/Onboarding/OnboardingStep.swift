import Foundation

// The 33-step onboarding story flow (docs/crunch-onboarding-v3-mockup.html, 31
// screens) plus two inserts: Attribution (after "3 · The solution") and Rating
// request (after "29 · Plan reveal"). Order here is the single source of truth —
// OnboardingCoordinator walks `OnboardingStep.allCases` in declaration order.
//
// `screenName` mirrors the mockup's data-name so Mixpanel funnel events line up
// with the design. `showsProgress`/`showsBack` drive the shared chrome; the
// progress *fraction* is computed by the coordinator from a step's rank among
// the progress-bearing steps, so inserting/removing a step needs no re-tuning.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome            // 1
    case problem            // 2
    case solution           // 3
    case attribution        // NEW — where did you hear about Crunch
    case name               // 4 (mockup)
    case raceType           // 5
    case raceDetails        // 6
    case hook               // 7 — "94 days / 280 meals"
    case sex                // 8
    case age                // 9
    case weight             // 10
    case height             // 11
    case trainingLevel      // 12
    case longestRun         // 13
    case activities         // 14
    case painPoints         // 15 — what's gone wrong before
    case reflection         // 16
    case bombshell          // 17 — "2 dinners"
    case bridge             // 18
    case diet               // 19
    case breakfast          // 20
    case lunch              // 21
    case dinner             // 22
    case liveAnswer         // 23 — Today-tab preview (climax)
    case connectApps        // 24
    case outcomeProjection  // 25
    case building           // 26
    case commitment         // 27
    case createAccount      // 28 — account boundary; writes everything
    case planReveal         // 29
    case ratingRequest      // NEW — SKStoreReviewController, no dedicated UI
    case notificationPrompt // 30
    case paywall            // 31

    var id: Int { rawValue }

    // Analytics screen name — mirrors the mockup's data-name attribute.
    var screenName: String {
        switch self {
        case .welcome:            return "1 · Welcome"
        case .problem:            return "2 · The problem"
        case .solution:           return "3 · The solution"
        case .attribution:        return "Attribution"
        case .name:               return "4 · Your name"
        case .raceType:           return "5 · Race type"
        case .raceDetails:        return "6 · Race name & date"
        case .hook:               return "7 · Hook — meals to race day"
        case .sex:                return "8 · Biological sex"
        case .age:                return "9 · Age"
        case .weight:             return "10 · Weight"
        case .height:             return "11 · Height"
        case .trainingLevel:      return "12 · Training level"
        case .longestRun:         return "13 · Longest current run"
        case .activities:         return "14 · Other weekly activities"
        case .painPoints:         return "15 · What's gone wrong before"
        case .reflection:         return "16 · Reflection"
        case .bombshell:          return "17 · The bombshell — two dinners"
        case .bridge:             return "18 · The bridge"
        case .diet:               return "19 · Dietary preferences"
        case .breakfast:          return "20 · Breakfast"
        case .lunch:              return "21 · Lunch"
        case .dinner:             return "22 · Dinner"
        case .liveAnswer:         return "23 · The live answer"
        case .connectApps:        return "24 · Connect Strava / Runna"
        case .outcomeProjection:  return "25 · Outcome projection"
        case .building:           return "26 · Building your plan"
        case .commitment:         return "27 · Commitment"
        case .createAccount:      return "28 · Create account"
        case .planReveal:         return "29 · Plan reveal"
        case .ratingRequest:      return "Rating request"
        case .notificationPrompt: return "30 · Notification pre-prompt"
        case .paywall:            return "31 · Paywall"
        }
    }

    // Story act (1 Hook / 2 Recognition / 3 Climax / 4 Conclusion) — display only.
    var act: Int {
        switch self {
        case .welcome, .problem, .solution, .attribution, .name, .raceType, .raceDetails, .hook:
            return 1
        case .sex, .age, .weight, .height, .trainingLevel, .longestRun, .activities,
             .painPoints, .reflection, .bombshell, .bridge:
            return 2
        case .diet, .breakfast, .lunch, .dinner, .liveAnswer, .connectApps:
            return 3
        case .outcomeProjection, .building, .commitment, .createAccount, .planReveal,
             .ratingRequest, .notificationPrompt, .paywall:
            return 4
        }
    }

    // Shared top chrome. Cinematic/statement/celebration screens carry neither a
    // progress bar nor a back button; the form spine carries both.
    var showsProgress: Bool {
        switch self {
        case .welcome, .problem, .solution, .reflection, .bridge, .building,
             .planReveal, .ratingRequest, .notificationPrompt, .paywall:
            return false
        default:
            return true
        }
    }

    var showsBack: Bool { showsProgress }

    // Single-select screens auto-advance after a short delay; everything else
    // advances on an explicit CTA.
    var autoAdvances: Bool {
        switch self {
        case .attribution, .raceType, .sex, .trainingLevel, .diet:
            return true
        default:
            return false
        }
    }

    // Steps that draw the progress bar, in flow order — used to compute a step's
    // progress fraction without hand-tuned percentages.
    static let progressBearing: [OnboardingStep] = allCases.filter { $0.showsProgress }
}
