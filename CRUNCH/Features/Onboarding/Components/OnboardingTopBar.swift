import SwiftUI

// Back button + progress track shared by the form-spine screens (mockup .topnav).
// Reads the coordinator for the current progress fraction and back availability.
struct OnboardingTopBar: View {
    let coordinator: OnboardingCoordinator
    var overlayStyle = false   // translucent chrome for full-bleed cinematic scenes

    var body: some View {
        HStack(spacing: 14) {
            if coordinator.current.showsBack && !coordinator.isFirst {
                Button {
                    coordinator.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OB.ink)
                        .frame(width: 38, height: 38)
                        .background(overlayStyle ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(OB.card))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(OB.cardBorder, lineWidth: 1))
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(overlayStyle ? OB.ink.opacity(0.22) : OB.track)
                    Capsule().fill(OB.trackFill)
                        .frame(width: max(0, geo.size.width * coordinator.progressFraction))
                }
            }
            .frame(height: 3)
        }
    }
}
