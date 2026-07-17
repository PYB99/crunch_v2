import SwiftUI

// A single tappable option card (mockup .opt) with a staggered entrance and a
// spring on selection. Radio (single-select) or box (multi-select) indicator.
struct OnboardingOptionRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var isMultiSelect = false
    let index: Int          // for the staggered entrance delay
    let action: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16.5, weight: .medium))
                        .foregroundStyle(OB.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(OB.ink2)
                    }
                }
                Spacer(minLength: 8)
                indicator
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? OB.ember.opacity(0.08) : OB.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? OB.ember : OB.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(OBPressStyle())
        .frame(minHeight: 44)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)
                .delay(0.05 + Double(index) * 0.07)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isMultiSelect ? 7 : 12)
                .stroke(isSelected ? OB.ember : OB.ink3, lineWidth: 2)
                .frame(width: 24, height: 24)
            RoundedRectangle(cornerRadius: isMultiSelect ? 4 : 8)
                .fill(OB.ember)
                .frame(width: 16, height: 16)
                .scaleEffect(isSelected ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .frame(width: 24, height: 24)
    }
}

// Spring scale-down on press, shared by option rows and other tappable cards.
struct OBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
