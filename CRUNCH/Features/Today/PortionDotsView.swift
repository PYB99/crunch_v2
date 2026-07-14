import SwiftUI

struct PortionDotsView: View {
    let filled: Int
    private let total = 4

    var body: some View {
        HStack(spacing: Theme.xs) {
            ForEach(0..<total, id: \.self) { index in
                if index < filled {
                    Circle()
                        .fill(Theme.brand)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .strokeBorder(Theme.subtle, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let level: String
        switch filled {
        case 1, 2: level = "normal serving"
        case 3:    level = "extra portion"
        default:   level = "double portion"
        }
        return "\(filled) of \(total) portions — \(level)"
    }
}

#Preview {
    ZStack {
        Theme.surface.ignoresSafeArea()
        VStack(spacing: Theme.md) {
            PortionDotsView(filled: 2)
            PortionDotsView(filled: 3)
            PortionDotsView(filled: 4)
        }
    }
}
