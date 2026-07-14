import SwiftUI

struct CoachInputView: View {
    @Binding var text: String
    let isDisabled: Bool
    let isOffline: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: Theme.xs) {
            if isOffline {
                Text("You're offline")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .bottom, spacing: Theme.sm) {
                TextField("Ask your Coach…", text: $text, axis: .vertical)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1...5)
                    .padding(.horizontal, Theme.sm)
                    .padding(.vertical, Theme.sm)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.inputRadius)
                            .strokeBorder(Theme.subtle, lineWidth: 1)
                    )
                    .onChange(of: text) { _, new in
                        if new.count > Constants.maxCoachInputLength {
                            text = String(new.prefix(Constants.maxCoachInputLength))
                        }
                    }
                    .disabled(isOffline)

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? Theme.brand : Theme.neutral)
                }
                .disabled(!canSend)
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, Theme.md)
        .padding(.top, Theme.sm)
        .padding(.bottom, Theme.sm)
        .background(Theme.surface)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isDisabled
            && !isOffline
    }
}

#Preview {
    VStack {
        Spacer()
        CoachInputView(text: .constant(""), isDisabled: false, isOffline: false) {}
        CoachInputView(text: .constant("What should I eat?"), isDisabled: true, isOffline: false) {}
        CoachInputView(text: .constant(""), isDisabled: false, isOffline: true) {}
    }
    .background(Theme.surface)
}
