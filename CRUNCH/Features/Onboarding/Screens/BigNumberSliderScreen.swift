import SwiftUI

// The four slider screens (age / weight / height / longest run). Big serif number
// with a spring "bump" on change (mockup .bignum). Weight and height carry a
// display-only metric/imperial toggle; the value is always stored in metric.
enum OBMeasure {
    case age, weight, height, longestRun

    var title: String {
        switch self {
        case .age:        return "How old are you?"
        case .weight:     return "What's your current weight?"
        case .height:     return "How tall are you?"
        case .longestRun: return "What's your longest run right now?"
        }
    }

    var subtitle: String {
        switch self {
        case .age:        return "Part of getting your baseline right."
        case .weight:     return "Portions are personal — a 58kg and an 82kg runner shouldn't eat the same plate."
        case .height:     return "Last biometric — almost there."
        case .longestRun: return "Your current long run — not your goal."
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .age:        return 16...80
        case .weight:     return 40...140
        case .height:     return 140...210
        case .longestRun: return 3...42
        }
    }

    var hasUnitToggle: Bool { self == .weight || self == .height }

    func value(_ data: OnboardingData) -> Double {
        switch self {
        case .age:        return Double(data.age)
        case .weight:     return data.weightKg
        case .height:     return data.heightCm
        case .longestRun: return Double(data.longestRunKm)
        }
    }

    func set(_ data: inout OnboardingData, _ v: Double) {
        switch self {
        case .age:        data.age = Int(v.rounded())
        case .weight:     data.weightKg = v.rounded()
        case .height:     data.heightCm = v.rounded()
        case .longestRun: data.longestRunKm = Int(v.rounded())
        }
    }
}

struct BigNumberSliderScreen: View {
    @Bindable var coordinator: OnboardingCoordinator
    let measure: OBMeasure

    @State private var bumped = false
    @State private var imperial = false

    private var value: Double { measure.value(coordinator.data) }

    var body: some View {
        OBScreen(coordinator: coordinator) {
            OBQuestionHeader(title: measure.title, subtitle: measure.subtitle)

            VStack(spacing: 8) {
                Spacer(minLength: 20)
                Text(displayNumber)
                    .font(OB.serif(96, .semibold))
                    .foregroundStyle(OB.ink)
                    .scaleEffect(bumped ? 1.08 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bumped)
                Text(displayUnit)
                    .font(.system(size: 16))
                    .foregroundStyle(OB.ink2)

                if measure.hasUnitToggle { unitToggle.padding(.top, 12) }

                Slider(
                    value: Binding(
                        get: { value },
                        set: { newValue in
                            measure.set(&coordinator.data, newValue)
                            triggerBump()
                        }
                    ),
                    in: measure.range,
                    step: 1
                )
                .tint(OB.trackFill)
                .padding(.top, 24)

                HStack {
                    Text("\(Int(measure.range.lowerBound))")
                    Spacer()
                    Text("\(Int(measure.range.upperBound))")
                }
                .font(.system(size: 13))
                .foregroundStyle(OB.ink3)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingCTA(title: "Continue") { coordinator.advance() }
        }
        .onAppear { imperial = coordinator.data.units == "imperial" }
    }

    // MARK: - Display

    private var displayNumber: String {
        switch measure {
        case .weight:
            return imperial ? "\(Int((value * 2.20462).rounded()))" : "\(Int(value))"
        case .height:
            guard imperial else { return "\(Int(value))" }
            let totalInches = value / 2.54
            let ft = Int(totalInches / 12)
            let inch = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            return "\(ft)′\(inch)″"
        default:
            return "\(Int(value))"
        }
    }

    private var displayUnit: String {
        switch measure {
        case .age:        return "years old"
        case .longestRun: return "km"
        case .weight:     return imperial ? "lb" : "kg"
        case .height:     return imperial ? "ft / in" : "cm"
        }
    }

    private var unitToggle: some View {
        let labels: (String, String) = measure == .weight ? ("kg", "lb") : ("cm", "ft/in")
        return HStack(spacing: 3) {
            toggleButton(labels.0, active: !imperial) { setImperial(false) }
            toggleButton(labels.1, active: imperial)  { setImperial(true) }
        }
        .padding(3)
        .background(Capsule().fill(OB.card))
        .overlay(Capsule().stroke(OB.cardBorder, lineWidth: 1))
    }

    private func toggleButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(active ? OB.ctaInk : OB.ink2)
                .padding(.vertical, 7)
                .padding(.horizontal, 16)
                .background(active ? AnyShapeStyle(OB.trackFill) : AnyShapeStyle(Color.clear))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func setImperial(_ v: Bool) {
        imperial = v
        coordinator.data.units = v ? "imperial" : "metric"
    }

    private func triggerBump() {
        bumped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { bumped = false }
    }
}
