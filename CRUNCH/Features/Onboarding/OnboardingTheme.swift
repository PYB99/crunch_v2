import SwiftUI

// Onboarding-only design tokens, lifted from the v3 mockup's *dark* theme
// (docs/crunch-onboarding-v3-mockup.html — the "dawn" variant is a dev tool and
// is ignored). This palette is intentionally richer than the app's base Theme:
// the story flow leans on an ember/jade/gold trio (portion levels, cinematic
// scenes, confetti) and a cream CTA that the four-tab app doesn't use.
//
// Fraunces (the mockup's display serif) isn't bundled; per the approved plan we
// approximate it with the system serif (New York) — a tasteful native stand-in.
enum OB {
    // Surfaces / ink
    static let bg         = Color(hex: "#0A0A0A")
    static let ink        = Color(hex: "#FFFFFF")
    static let ink2       = Color(hex: "#A8A29A")
    static let ink3       = Color(hex: "#6E6862")
    static let card       = Color(hex: "#161616")
    static let cardBorder = Color(hex: "#262626")

    // Accents (the portion-level trio)
    static let ember = Color(hex: "#E8703A")   // "double" / problem
    static let jade  = Color(hex: "#63C08F")   // "good" / solution
    static let gold  = Color(hex: "#DFAF56")   // "extra" / neutral

    // CTA + track
    static let ctaBg    = Color(hex: "#F5F1EA")
    static let ctaInk   = Color(hex: "#141210")
    static let track    = Color(hex: "#2A2A2A")
    static let trackFill = Color(hex: "#F5F1EA")

    // MARK: - Type (Inter → SF for body; Fraunces → New York for display)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // Standard horizontal gutter from the mockup (26px).
    static let gutter: CGFloat = 26
}
