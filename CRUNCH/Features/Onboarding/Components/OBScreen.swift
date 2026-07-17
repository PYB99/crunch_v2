import SwiftUI

// Standard form-spine layout (mockup .screen): 64/26/30 padding, optional top
// bar, top-aligned content, footer (CTA) pinned to the bottom. Cinematic scenes
// and full-bleed screens don't use this — they compose their own layout.
struct OBScreen<Content: View, Footer: View>: View {
    let coordinator: OnboardingCoordinator
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if coordinator.current.showsProgress {
                OnboardingTopBar(coordinator: coordinator)
                    .padding(.bottom, 22)
            }
            content()
            Spacer(minLength: 16)
            footer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, OB.gutter)
        .padding(.top, 64)
        .padding(.bottom, 30)
        .background(OB.bg.ignoresSafeArea())
    }
}

// Serif question title + secondary subtitle (mockup .q-title / .q-sub). Supports
// a live-bound name via markdown-free interpolation done by the caller.
struct OBQuestionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OB.serif(29, .semibold))
                .foregroundStyle(OB.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 26)
    }
}

// "Tap to auto-advance" hint under single-select lists.
struct OBHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(OB.ink3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
    }
}
