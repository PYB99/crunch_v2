import Foundation

// Cross-tab navigation, driven by the push-notification deep link today and
// the "Ask your Coach →" placeholder buttons in TodayView. pendingCoachConversationId
// is a buffered value rather than a one-shot event so a cold-start launch
// (CoachView not yet mounted when the notification delegate fires) still
// lands on the right conversation once CoachView appears and consumes it.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    private init() {}

    var selectedTab: MainTabView.Tab = .today
    var pendingCoachConversationId: UUID?

    func openCoachConversation(_ id: UUID?) {
        pendingCoachConversationId = id
        selectedTab = .coach
    }
}
