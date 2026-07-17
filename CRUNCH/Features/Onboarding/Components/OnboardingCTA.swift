import SwiftUI

// Primary onboarding CTA — the mockup's cream pill with a spring press
// (scale .965). Distinct from the app's orange PrimaryButton by design; the
// story flow uses cream so the ember accent stays reserved for meaning.
struct OnboardingCTA: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    var showsChevron = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(OB.ctaInk)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    if showsChevron {
                        Text("›").font(.system(size: 17, weight: .bold))
                    }
                }
            }
            .foregroundStyle(OB.ctaInk)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(OB.ctaBg)
            .clipShape(Capsule())
            .opacity(isDisabled || isLoading ? 0.5 : 1.0)
            .scaleEffect(pressed ? 0.965 : 1.0)
            .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .frame(minHeight: 44)
        ._onPressChange { pressed = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pressed)
    }
}

// Underlined text button — the mockup's ".cta.secondary".
struct OnboardingSecondaryCTA: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(OB.ink2)
                .underline()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.top, 2)
    }
}

// Lightweight press tracker so the CTA can spring on touch-down.
private extension View {
    func _onPressChange(_ change: @escaping (Bool) -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in change(true) }
                .onEnded { _ in change(false) }
        )
    }
}
