import SwiftUI

/// Stacked vertical bars showing precipitation intensity. Pure-mm/h input so
/// it can be reused by the rain widget and the Live Activity.
struct RainBarChart: View {
    let values: [Double]
    let barSpacing: CGFloat

    init(values: [Double], barSpacing: CGFloat = 1) {
        self.values = values
        self.barSpacing = barSpacing
    }

    /// Convenience for callers that already have `RainSample` values.
    init(samples: [RainSample], barSpacing: CGFloat = 1) {
        self.init(values: samples.map { $0.mmPerHour }, barSpacing: barSpacing)
    }

    var body: some View {
        GeometryReader { geo in
            let n = max(values.count, 1)
            let totalSpacing = barSpacing * CGFloat(max(n - 1, 0))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(n))
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(values.indices, id: \.self) { i in
                    let h = RainBarChart.height(forMmPerHour: values[i],
                                                full: geo.size.height)
                    Capsule(style: .continuous)
                        .fill(RainIntensity.color(forMmPerHour: values[i]))
                        .frame(width: barWidth, height: max(h, 2))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    /// Maps mm/h to a 0..1 ratio then to a pixel height. Uses a square-root
    /// curve so light drizzle still has a visible bar while keeping the
    /// scale sane for downpours (extracted for unit tests).
    static func height(forMmPerHour mm: Double, full: CGFloat) -> CGFloat {
        let clamped = max(0, min(mm, 20))
        let ratio = (clamped / 20).squareRoot()
        return CGFloat(ratio) * full
    }
}
