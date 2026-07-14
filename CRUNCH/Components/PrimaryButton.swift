import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.textInverse)
                } else {
                    Text(title)
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.brand)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
            .opacity(isDisabled || isLoading ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .frame(minWidth: 44, minHeight: 44)
    }
}

#Preview {
    VStack(spacing: Theme.md) {
        PrimaryButton(title: "Get Started") {}
        PrimaryButton(title: "Loading", isLoading: true) {}
        PrimaryButton(title: "Disabled", isDisabled: true) {}
    }
    .padding()
    .background(Theme.surface)
}
