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

/// Custom weather glyph that draws an outlined cloud + condition-specific
/// accents. SF Symbols' `cloud.fill` is itself white and disappears on the
/// `owSurfaceCard` background; this gives a strong silhouette by stacking
/// three filled circles on top of three stroked ones — the inner stroke
/// crossings get hidden behind the upper fills, leaving only the outer
/// perimeter visible as a single clean outline.
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
        switch kind {
        case .clear:
            SunWithRays(size: size,
                        centerX: 32, centerY: 28,
                        discR: 12, rayLen: 8.5, rayWidth: 3,
                        rayCount: 8)
        case .partlyCloudy:
            // Tucked into the upper-left so the cloud (drawn after) covers
            // only the right-side rays — what remains visible reads as a
            // sun peeking out from behind a cloud.
            SunWithRays(size: size,
                        centerX: 18, centerY: 20,
                        discR: 7.5, rayLen: 5.5, rayWidth: 2.4,
                        rayCount: 8)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var cloudLayer: some View {
        switch kind {
        case .clear:
            EmptyView()
        case .partlyCloudy:
            CloudCluster(size: size, shifted: true)
        default:
            CloudCluster(size: size, shifted: false)
        }
    }

    @ViewBuilder
    private var accentLayer: some View {
        switch kind {
        case .rain:    RainAccents(size: size, intense: true)
        case .drizzle: RainAccents(size: size, intense: false)
        case .snow:    SnowDots(size: size)
        case .thunder: Lightning(size: size)
        case .fog:     FogBars(size: size)
        default:       EmptyView()
        }
    }
}

// MARK: - Sun

private struct SunWithRays: View {
    let size: CGFloat
    let centerX: CGFloat   // in 64-unit design space
    let centerY: CGFloat
    let discR: CGFloat
    let rayLen: CGFloat
    let rayWidth: CGFloat
    let rayCount: Int

    var body: some View {
        let s = size / 64
        let extent = (discR + rayLen + 2) * 2 * s
        ZStack {
            ForEach(0..<rayCount, id: \.self) { i in
                Capsule()
                    .fill(Color.owSun)
                    .frame(width: rayWidth * s, height: rayLen * s)
                    .offset(y: -(discR + rayLen * 0.55) * s)
                    .rotationEffect(.degrees(Double(i) * 360.0 / Double(rayCount)))
            }
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.97, blue: 0.50),
                        Color.owSun,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: discR * s
                ))
                .frame(width: discR * 2 * s, height: discR * 2 * s)
        }
        .frame(width: extent, height: extent)
        .position(x: centerX * s, y: centerY * s)
    }
}

// MARK: - Cloud

private struct CloudCluster: View {
    let size: CGFloat
    /// `true` for partly-cloudy — shifts the cloud down-right so the sun
    /// (drawn earlier in the ZStack, upper-left) peeks above it.
    let shifted: Bool

    var body: some View {
        let s = size / 64
        // (cx, cy, r) for each lobe in the 64-unit design space.
        let lobes: [(CGFloat, CGFloat, CGFloat)] = shifted
            ? [(30, 44, 10), (48, 44, 10), (38, 30, 11)]
            : [(22, 40, 12), (42, 40, 12), (32, 26, 13)]

        let stroke = Color(red: 0.30, green: 0.34, blue: 0.40)
        let lineWidth = max(3.0, size / 10)
        let fill = Color.white

        return ZStack {
            // Stroke pass: outer half of each ring extends just beyond the
            // geometric edge of its lobe. Inner stroke crossings are hidden
            // by the fill pass below.
            ForEach(lobes.indices, id: \.self) { i in
                Circle()
                    .stroke(stroke, lineWidth: lineWidth)
                    .frame(width: lobes[i].2 * 2 * s,
                           height: lobes[i].2 * 2 * s)
                    .position(x: lobes[i].0 * s, y: lobes[i].1 * s)
            }
            // Fill pass: each disc covers up to its own edge, hiding the
            // strokes of overlapping lobes in the interior.
            ForEach(lobes.indices, id: \.self) { i in
                Circle()
                    .fill(fill)
                    .frame(width: lobes[i].2 * 2 * s,
                           height: lobes[i].2 * 2 * s)
                    .position(x: lobes[i].0 * s, y: lobes[i].1 * s)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Rain / drizzle

private struct RainAccents: View {
    let size: CGFloat
    /// `true` = rain (larger, fully-saturated drops); `false` = drizzle.
    let intense: Bool

    var body: some View {
        let s = size / 64
        let positions: [CGFloat] = [20, 32, 44]
        let dropW: CGFloat = intense ? 5 : 3.6
        let dropH: CGFloat = intense ? 10 : 7
        let yCenter: CGFloat = intense ? 57 : 56
        let color = intense ? Color.owAccent : Color.owAccent.opacity(0.85)

        return ZStack {
            ForEach(positions.indices, id: \.self) { i in
                Teardrop()
                    .fill(color)
                    .frame(width: dropW * s, height: dropH * s)
                    .rotationEffect(.degrees(18))
                    .position(x: positions[i] * s, y: yCenter * s)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Pointed top, round bottom — like a falling rain drop. Traced as four
/// cubic Béziers so the corner at the top stays crisp.
private struct Teardrop: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let midY = rect.minY + h * 0.65
        var p = Path()
        p.move(to: CGPoint(x: cx, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control1: CGPoint(x: cx + w * 0.20, y: rect.minY + h * 0.12),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY),
            control2: CGPoint(x: cx + w * 0.40, y: rect.maxY)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX, y: midY),
            control1: CGPoint(x: cx - w * 0.40, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.35),
            control2: CGPoint(x: cx - w * 0.20, y: rect.minY + h * 0.12)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Snow / Thunder / Fog

private struct SnowDots: View {
    let size: CGFloat
    private let positions: [(CGFloat, CGFloat)] = [(20, 56), (32, 58), (44, 56)]

    var body: some View {
        let s = size / 64
        ZStack {
            ForEach(positions.indices, id: \.self) { i in
                Circle()
                    .fill(Color.owInkSecondary)
                    .frame(width: 4 * s, height: 4 * s)
                    .position(x: positions[i].0 * s, y: positions[i].1 * s)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct Lightning: View {
    let size: CGFloat

    var body: some View {
        let s = size / 64
        ZStack {
            BoltShape()
                .fill(Color.owSun)
                .frame(width: 12 * s, height: 17 * s)
                .position(x: 32 * s, y: 56 * s)
        }
        .frame(width: size, height: size)
    }
}

private struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.58, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX,             y: rect.minY + h * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.42,  y: rect.minY + h * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.22,  y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX,             y: rect.minY + h * 0.42))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.50,  y: rect.minY + h * 0.42))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.05,  y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct FogBars: View {
    let size: CGFloat

    var body: some View {
        let s = size / 64
        ZStack {
            Capsule()
                .fill(Color.owInkSecondary)
                .frame(width: 32 * s, height: 2.4 * s)
                .position(x: 26 * s, y: 56 * s)
            Capsule()
                .fill(Color.owInkSecondary)
                .frame(width: 32 * s, height: 2.4 * s)
                .position(x: 30 * s, y: 60 * s)
        }
        .frame(width: size, height: size)
    }
}
