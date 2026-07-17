import SwiftUI
import RevenueCat

// Screen 31 — the paywall (mockup .pay). Outcome-selling headline, value list,
// social proof, two plans (annual pre-selected), a Blinkist-style trial timeline,
// and view-all / exit-intent sheets. Completing (purchase, skip, or restore)
// finishes onboarding → main tabs. Entitlement gating proper is Phase 9.
struct PaywallScreen: View {
    let coordinator: OnboardingCoordinator

    @State private var selectedAnnual = true
    @State private var packages: [Package] = []
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var sheet: Sheet?

    private enum Sheet: Identifiable { case allPlans, exit; var id: Int { hashValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button { sheet = .exit } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OB.ink2)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(OB.card))
                            .overlay(Circle().stroke(OB.cardBorder, lineWidth: 1))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                Text("Your \(raceLabel) plan is ready to run")
                    .font(OB.serif(27, .semibold))
                    .foregroundStyle(OB.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("Unlock every daily portion from tomorrow's run all the way to the start line.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10).padding(.bottom, 18)

                features
                socialProof.padding(.top, 14)
                plans.padding(.top, 14)

                Text(.init("**Just $1.73 a week** — less than one race-day gel."))
                    .font(.system(size: 12.5)).foregroundStyle(OB.ink2)
                    .frame(maxWidth: .infinity).padding(.top, 4)
                Button { sheet = .allPlans } label: {
                    Text("View all plans").font(.system(size: 12.5)).underline().foregroundStyle(OB.ink2)
                }
                .frame(maxWidth: .infinity).frame(minHeight: 44)

                trialTimeline.padding(.top, 6)

                Text("7 days free. We'll remind you 2 days before it ends — no surprise charge.")
                    .font(.system(size: 12)).foregroundStyle(OB.ink2)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 8)
                Text("No commitment · cancel anytime")
                    .font(.system(size: 12.5)).foregroundStyle(OB.ink3)
                    .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 14)

                if let errorMessage {
                    Text(errorMessage).font(.system(size: 13)).foregroundStyle(OB.ember)
                        .frame(maxWidth: .infinity).padding(.bottom, 8)
                }

                OnboardingCTA(title: "Start my 7-day free trial", isLoading: isPurchasing, showsChevron: true) {
                    Task { await startTrial() }
                }

                scienceCard.padding(.top, 16)
                legalRow.padding(.top, 14)
            }
            .padding(.horizontal, OB.gutter)
            .padding(.top, 64)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
        .task { packages = await RevenueCatService.shared.currentPackages() }
        .sheet(item: $sheet) { which in
            sheetContent(which)
                .presentationDetents([.height(which == .allPlans ? 300 : 260)])
                .presentationBackground(OB.bg)
        }
    }

    // MARK: - Sections

    private var features: some View {
        VStack(alignment: .leading, spacing: 11) {
            feature("Daily portions tuned to every run and rest day")
            feature("Auto-sync with Strava & Runna — portions update themselves")
            feature("Your carb-load & taper handled automatically in race week")
            feature("A coach that knows your meals, your race, and your training")
        }
    }

    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("✓").font(.system(size: 14, weight: .bold)).foregroundStyle(OB.jade)
            Text(text).font(.system(size: 14)).foregroundStyle(OB.ink)
        }
    }

    private var socialProof: some View {
        VStack(spacing: 8) {
            (Text("★★★★★  ").foregroundStyle(OB.gold)
             + Text("4.9 · early runners").font(.system(size: 13, weight: .semibold)).foregroundStyle(OB.ink))
                .font(.system(size: 15))
            Text("\"First marathon I didn't hit the wall. I finally knew what to eat the night before.\" — Dana")
                .font(.system(size: 13)).italic().foregroundStyle(OB.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var plans: some View {
        HStack(spacing: 10) {
            planCard(title: "Monthly", price: "$14.99", per: "per month", isHero: !selectedAnnual, badge: nil) {
                selectedAnnual = false
            }
            planCard(title: "Annual", price: "$89.99", per: "per year", isHero: selectedAnnual, badge: "BEST VALUE") {
                selectedAnnual = true
            }
        }
    }

    private func planCard(title: String, price: String, per: String, isHero: Bool, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(OB.ink)
                    Spacer()
                    Circle().stroke(isHero ? OB.ember : OB.ink3, lineWidth: 2)
                        .background(Circle().fill(isHero ? OB.ember : .clear))
                        .frame(width: 20, height: 20)
                }
                Text(price).font(OB.serif(19, .semibold)).foregroundStyle(OB.ink)
                Text(per).font(.system(size: 11.5)).foregroundStyle(OB.ink2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(OB.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isHero ? OB.ember : OB.cardBorder, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(Capsule().fill(OB.ember))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var trialTimeline: some View {
        HStack(alignment: .top, spacing: 0) {
            timelineStep("Today", "Full access, free")
            timelineStep("Day 6", "Reminder email")
            timelineStep("Day 7", "Trial ends")
        }
        .overlay(alignment: .top) {
            Rectangle().fill(OB.track).frame(height: 2).padding(.horizontal, 40).padding(.top, 8)
        }
    }

    private func timelineStep(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 8) {
            Circle().fill(OB.card).overlay(Circle().stroke(OB.trackFill, lineWidth: 2)).frame(width: 18, height: 18)
            Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(OB.ink)
            Text(sub).font(.system(size: 10.5)).foregroundStyle(OB.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var scienceCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Built on peer-reviewed sports science").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(OB.ink)
            Text("Burke 2011 · Jeukendrup 2011 · Morton 2018 · ISSN 2017").font(.system(size: 11.5)).foregroundStyle(OB.ink2)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(OB.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OB.cardBorder, lineWidth: 1))
    }

    private var legalRow: some View {
        HStack(spacing: 22) {
            Button("Restore Purchase") { Task { await restore() } }
            Text("Terms")
            Text("Privacy")
        }
        .font(.system(size: 12)).foregroundStyle(OB.ink3)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sheetContent(_ which: Sheet) -> some View {
        VStack(spacing: 12) {
            Capsule().fill(OB.cardBorder).frame(width: 38, height: 4).padding(.top, 10)
            switch which {
            case .allPlans:
                Text("Choose your plan").font(OB.serif(20, .semibold)).foregroundStyle(OB.ink)
                Text("All plans include everything. 7-day free trial on annual.")
                    .font(.system(size: 13)).foregroundStyle(OB.ink2).multilineTextAlignment(.center)
                OnboardingCTA(title: "Done") { sheet = nil }
            case .exit:
                Text("Not ready for a year?").font(OB.serif(20, .semibold)).foregroundStyle(OB.ink)
                Text("Start month-to-month and switch anytime — your plan's already built.")
                    .font(.system(size: 13)).foregroundStyle(OB.ink2).multilineTextAlignment(.center)
                OnboardingCTA(title: "Start monthly") {
                    selectedAnnual = false; sheet = nil
                    Task { await startTrial() }
                }
                OnboardingSecondaryCTA(title: "Maybe later") {
                    sheet = nil
                    Task { await coordinator.finish() }
                }
            }
        }
        .padding(.horizontal, OB.gutter).padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var raceLabel: String {
        let n = coordinator.data.raceName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "race" : n
    }

    private func targetPackage() -> Package? {
        let productId = selectedAnnual ? Constants.revenueCatAnnualProduct : Constants.revenueCatMonthlyProduct
        return packages.first { $0.storeProduct.productIdentifier == productId } ?? packages.first
    }

    private func startTrial() async {
        errorMessage = nil
        // Dev fallback: no offerings configured → don't trap the runner.
        guard let package = targetPackage() else {
            await coordinator.finish(); return
        }
        isPurchasing = true
        let success = await RevenueCatService.shared.purchase(package)
        isPurchasing = false
        if success {
            MixpanelService.track(.subscriptionStarted(
                productId: package.storeProduct.productIdentifier, isTrial: true))
            await coordinator.finish()
        } else {
            errorMessage = "Purchase didn't complete. You can try again."
        }
    }

    private func restore() async {
        await RevenueCatService.shared.refreshEntitlements()
        if RevenueCatService.shared.isPro { await coordinator.finish() }
    }
}
