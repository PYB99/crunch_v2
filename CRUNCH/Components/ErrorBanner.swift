import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        Button {
            onRetry?()
        } label: {
            HStack(spacing: Theme.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.error)
                Text(message)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(Theme.md)
            .background(Theme.error.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.inputRadius)
                    .strokeBorder(Theme.error.opacity(0.4), lineWidth: 1)
            )
        }
        .disabled(onRetry == nil)
        .frame(minHeight: 44)
    }
}

#Preview {
    VStack(spacing: Theme.md) {
        ErrorBanner(message: "Something went wrong. Tap to retry.") {}
        ErrorBanner(message: "No internet connection.")
    }
    .padding()
    .background(Theme.surface)
}
