import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    enum Tab { case today, week, nutrition, coach }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tag(Tab.today)
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }

            WeekView()
                .tag(Tab.week)
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }

            NutritionView()
                .tag(Tab.nutrition)
                .tabItem {
                    Label("Nutrition", systemImage: "leaf.fill")
                }

            CoachView()
                .tag(Tab.coach)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.fill")
                }
        }
        .tint(Theme.brand)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.backgroundColor = UIColor(Theme.surface)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    @ViewBuilder
    private func placeholderTab(title: String, systemImage: String) -> some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            VStack(spacing: Theme.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textSecondary)
                Text(title)
                    .font(Theme.heading)
                    .foregroundStyle(Theme.textPrimary)
                Text("Coming in a future phase.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter.shared)
}
