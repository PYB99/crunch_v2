import Foundation

enum PortionLevel: Equatable {
    case normal     // multiplier ≤ 1.25×
    case extra      // 1.25× < multiplier ≤ 1.75×
    case double     // multiplier > 1.75×

    var label: String {
        switch self {
        case .normal: "Normal portions"
        case .extra:  "Extra portion today"
        case .double: "Double portion today"
        }
    }

    var dotCount: Int {
        switch self {
        case .normal: 2
        case .extra:  3
        case .double: 4
        }
    }
}

struct PortionResult {
    let meal: Meal
    let multiplier: Double
    let level: PortionLevel
    let targetCarbsG: Double
    let targetProteinG: Double
    let targetFatG: Double
    let breakdown: String
    let gramDetails: String
}
