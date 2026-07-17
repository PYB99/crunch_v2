import SwiftUI

// Card-style input matching the mockup .field input/textarea: filled card, 1.5px
// border that turns ember on focus, 16px radius.
struct OBFieldStyle: ViewModifier {
    var focused: Bool
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(OB.ink)
            .tint(OB.ember)
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
            .background(RoundedRectangle(cornerRadius: 16).fill(OB.card))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(focused ? OB.ember : OB.cardBorder, lineWidth: 1.5)
            )
    }
}

extension View {
    func obField(focused: Bool) -> some View { modifier(OBFieldStyle(focused: focused)) }
}

// Small caption label above a field (mockup .field label).
struct OBFieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(OB.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
