import SwiftUI

// MARK: - Single message bubble

struct CoachMessageView: View {
    let message: CoachMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: Theme.xl) }

            Text(message.content)
                .font(Theme.body)
                .foregroundStyle(message.role == .user ? Theme.textInverse : Theme.textPrimary)
                .padding(.horizontal, Theme.md)
                .padding(.vertical, Theme.sm)
                .background(message.role == .user ? Theme.brand : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .accessibilityLabel(
                    message.role == .assistant
                        ? "Coach said: \(message.content)"
                        : message.content
                )

            if message.role == .assistant { Spacer(minLength: Theme.xl) }
        }
        .padding(.horizontal, Theme.md)
        .padding(.vertical, Theme.xs)
    }
}

// MARK: - Animated typing indicator (3 dots)

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: Theme.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 8, height: 8)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, Theme.md)
            .padding(.vertical, Theme.sm)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .accessibilityLabel("Coach is typing")

            Spacer(minLength: Theme.xl)
        }
        .padding(.horizontal, Theme.md)
        .padding(.vertical, Theme.xs)
        .onAppear { animating = true }
    }
}

// MARK: - Error coach bubble with retry

struct ErrorCoachBubble: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.xs) {
                Text("Something went wrong.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                Button("Tap to retry") { onRetry() }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.brand)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Theme.md)
            .padding(.vertical, Theme.sm)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.error.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Spacer(minLength: Theme.xl)
        }
        .padding(.horizontal, Theme.md)
        .padding(.vertical, Theme.xs)
    }
}

// MARK: - Previews

#Preview("User bubble") {
    CoachMessageView(
        message: CoachMessage(
            id: UUID(), conversationId: UUID(), userId: "u",
            role: .user, content: "What should I eat before my long run?",
            createdAt: Date()
        )
    )
    .background(Theme.surface)
}

#Preview("Coach bubble") {
    CoachMessageView(
        message: CoachMessage(
            id: UUID(), conversationId: UUID(), userId: "u",
            role: .assistant,
            content: "Since you've got a long run tomorrow, I'd load up on pasta tonight — double your usual bowl.",
            createdAt: Date()
        )
    )
    .background(Theme.surface)
}

#Preview("Typing indicator") {
    TypingIndicatorView()
        .background(Theme.surface)
}
