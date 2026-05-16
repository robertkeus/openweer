import SwiftUI

/// Shared visual tokens for the OpenWeer widgets. Centralised so the three
/// widget families stay typographically consistent — Dutch design tradition
/// is restraint, so one type scale and one accent do the heavy lifting.
enum WidgetTheme {

    // MARK: - Typography

    /// The single hero number on a widget — temperature, countdown, etc.
    static func hero(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// One-line bold statement under the hero (e.g. "Het blijft droog").
    static let statement: Font = .system(.headline, design: .rounded).weight(.semibold)

    /// Small caps caption used for location names — gives a tiny dose of
    /// editorial polish without breaking the system look.
    static let eyebrow: Font = .system(.caption2, design: .default)
        .weight(.semibold)
        .smallCaps()

    /// Monospaced metadata — timestamps, mm totals, day labels.
    static let meta: Font = .caption2.monospacedDigit()

    /// Body caption (feels-like, axis labels).
    static let support: Font = .caption.weight(.medium)

    // MARK: - Spacing

    static let pad: CGFloat = 2
    static let gap: CGFloat = 8
    static let block: CGFloat = 14

    // MARK: - Background

    /// Subtle vertical tint over the surface card — adds depth without
    /// drowning the content. Uses owSurfaceCard so it follows dark mode.
    static func surface(tinted with: Color = .clear) -> some View {
        ZStack {
            Color.owSurfaceCard
            LinearGradient(
                colors: [with.opacity(0.10), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Tint color suggested by a `ConditionKind`. Keeps the palette narrow.
    static func tint(for kind: ConditionKind) -> Color {
        switch kind {
        case .clear, .partlyCloudy:    return .owSun
        case .rain, .drizzle, .thunder: return .owAccent
        case .snow, .fog:               return .owInkSecondary
        default:                        return .clear
        }
    }
}

// MARK: - View helpers

extension View {
    /// Location-name eyebrow row, used at the top of every widget. Uppercased
    /// in small caps, secondary ink, tightly tracked.
    func widgetEyebrow(_ text: String) -> some View {
        modifier(_Eyebrow(text: text))
    }
}

private struct _Eyebrow: ViewModifier {
    let text: String
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: WidgetTheme.pad) {
            Text(text)
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .unredacted()
            content
        }
    }
}
