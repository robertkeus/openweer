import SwiftUI

/// Maps WMO weather codes (Open-Meteo) to a `ConditionKind`.
enum WeatherIcon {
    static func kind(forWmoCode code: Int?) -> ConditionKind {
        guard let code else { return .unknown }
        switch code {
        case 0:                  return .clear
        case 1, 2, 3:            return .partlyCloudy
        case 45, 48:             return .fog
        case 51, 53, 55, 56, 57: return .drizzle
        case 61, 63, 65, 66, 67: return .rain
        case 71, 73, 75, 77:     return .snow
        case 80, 81, 82:         return .rain
        case 85, 86:             return .snow
        case 95, 96, 99:         return .thunder
        default:                 return .cloudy
        }
    }
}

/// SwiftUI port of the web's `ConditionGlyph` SVG. We draw a stroked cloud
/// + condition-specific accents instead of using SF Symbols, because the
/// system cloud glyphs are themselves white and disappear against the white
/// `owSurfaceCard` background. The dark stroke keeps the silhouette readable
/// on any surface.
struct ConditionGlyph: View {
    let kind: ConditionKind
    let size: CGFloat

    var body: some View {
        ZStack {
            sunLayer
            cloudLayer
            accentLayer
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sunLayer: some View {
        if kind == .clear || kind == .partlyCloudy {
            SunDisc()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.96, blue: 0.62),
                        Color.owSun,
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4375),
                    startRadius: 0,
                    endRadius: size * 0.22
                ))
            SunRays()
                .stroke(Color.owSun.opacity(0.85),
                        style: StrokeStyle(lineWidth: max(1, size / 32),
                                           lineCap: .round))
        }
    }

    @ViewBuilder
    private var cloudLayer: some View {
        if kind != .clear {
            CloudShape()
                .fill(LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        Color(red: 0.82, green: 0.84, blue: 0.87).opacity(0.95),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            CloudShape()
                .stroke(Color(red: 0.55, green: 0.58, blue: 0.62),
                        lineWidth: max(0.6, size / 50))
        }
    }

    @ViewBuilder
    private var accentLayer: some View {
        switch kind {
        case .rain:
            RainDrops(small: false)
                .stroke(Color.owAccent,
                        style: StrokeStyle(lineWidth: max(1, size / 32),
                                           lineCap: .round))
        case .drizzle:
            RainDrops(small: true)
                .stroke(Color.owAccent.opacity(0.85),
                        style: StrokeStyle(lineWidth: max(0.8, size / 42),
                                           lineCap: .round))
        case .snow:
            SnowDots()
                .fill(Color.owInkSecondary)
        case .thunder:
            LightningShape()
                .fill(Color.owSun)
            LightningShape()
                .stroke(Color(red: 0.62, green: 0.42, blue: 0.16),
                        lineWidth: max(0.5, size / 80))
        case .fog:
            FogLines()
                .stroke(Color.owInkSecondary,
                        style: StrokeStyle(lineWidth: max(0.8, size / 40),
                                           lineCap: .round))
        case .clear, .partlyCloudy, .cloudy, .unknown:
            EmptyView()
        }
    }
}

// MARK: - Shapes (64×64 design coordinate space, scaled to bounds)

private struct SunDisc: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        let r = 11 * s
        let cx = rect.minX + 32 * s
        let cy = rect.minY + 28 * s
        return Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                      width: r * 2, height: r * 2))
    }
}

private struct SunRays: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        let rays: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (32,  6, 32, 11),
            (50, 28, 55, 28),
            ( 9, 28, 14, 28),
            (46, 14, 50, 10),
            (18, 14, 14, 10),
        ]
        for (x1, y1, x2, y2) in rays {
            path.move(to: p(x1, y1))
            path.addLine(to: p(x2, y2))
        }
        return path
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(14, 50))
        // bottom edge, sweeping left → right under the cloud
        path.addCurve(to: p(36, 50),
                      control1: p(20, 60),
                      control2: p(30, 60))
        // right side / bottom-right lobe
        path.addCurve(to: p(50, 44),
                      control1: p(43, 53),
                      control2: p(50, 52))
        // top-right lobe
        path.addCurve(to: p(42, 30),
                      control1: p(56, 36),
                      control2: p(52, 26))
        // top peak (highest lobe)
        path.addCurve(to: p(22, 28),
                      control1: p(34, 16),
                      control2: p(26, 16))
        // upper-left descent
        path.addCurve(to: p(12, 38),
                      control1: p(14, 28),
                      control2: p(10, 32))
        // left side back to start
        path.addCurve(to: p(14, 50),
                      control1: p(8, 46),
                      control2: p(8, 50))
        path.closeSubpath()
        return path
    }
}

private struct RainDrops: Shape {
    let small: Bool
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        let drops: [(CGFloat, CGFloat, CGFloat, CGFloat)] = small
            ? [(20, 54, 19, 58), (28, 54, 27, 58), (36, 54, 35, 58)]
            : [(20, 54, 18, 60), (28, 54, 26, 60), (36, 54, 34, 60)]
        var path = Path()
        for (x1, y1, x2, y2) in drops {
            path.move(to: p(x1, y1))
            path.addLine(to: p(x2, y2))
        }
        return path
    }
}

private struct SnowDots: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        let r = 1.4 * s
        var path = Path()
        for (cx, cy) in [(20.0, 56.0), (28.0, 58.0), (36.0, 56.0)] {
            path.addEllipse(in: CGRect(
                x: rect.minX + CGFloat(cx) * s - r,
                y: rect.minY + CGFloat(cy) * s - r,
                width: r * 2, height: r * 2
            ))
        }
        return path
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(30, 50))
        path.addLine(to: p(27, 57))
        path.addLine(to: p(31, 57))
        path.addLine(to: p(29, 63))
        path.addLine(to: p(36, 54))
        path.addLine(to: p(32, 54))
        path.addLine(to: p(34, 50))
        path.closeSubpath()
        return path
    }
}

private struct FogLines: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(10, 56)); path.addLine(to: p(42, 56))
        path.move(to: p(14, 60)); path.addLine(to: p(46, 60))
        return path
    }
}
