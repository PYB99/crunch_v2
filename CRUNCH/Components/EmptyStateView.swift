import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            VStack(spacing: Theme.xs) {
                Text(title)
                    .font(Theme.subheading)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(Theme.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

#Preview {
    EmptyStateView(
        systemImage: "fork.knife",
        title: "No meals yet",
        subtitle: "Add your usual meals and Crunch will calculate your exact portions.",
        actionLabel: "+ Add your first meal"
    ) {}
    .padding()
    .background(Theme.surface)
}
