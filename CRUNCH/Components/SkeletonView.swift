import SwiftUI

struct SkeletonView: View {
    let height: CGFloat
    var cornerRadius: CGFloat = Theme.cardRadius
    @State private var opacity: Double = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.card)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    opacity = 0.9
                }
            }
    }
}

#Preview {
    VStack(spacing: Theme.sm) {
        SkeletonView(height: 90)
        SkeletonView(height: 60)
        SkeletonView(height: 120)
    }
    .padding()
    .background(Theme.surface)
}
