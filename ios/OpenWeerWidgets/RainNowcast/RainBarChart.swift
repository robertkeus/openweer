import SwiftUI

/// Stacked vertical bars showing precipitation intensity. Pure-mm/h input so
/// it can be reused by the rain widget and the Live Activity.
struct RainBarChart: View {
    let values: [Double]
    let barSpacing: CGFloat
    /// 0..<values.count where the "now" indicator should be drawn, or nil.
    let nowIndex: Int?

    init(values: [Double], nowIndex: Int? = nil, barSpacing: CGFloat = 1.5) {
        self.values = values
        self.nowIndex = nowIndex
        self.barSpacing = barSpacing
    }

    /// Convenience for callers that already have `RainSample` values.
    init(samples: [RainSample], nowIndex: Int? = nil, barSpacing: CGFloat = 1.5) {
        self.init(values: samples.map { $0.mmPerHour },
                  nowIndex: nowIndex,
                  barSpacing: barSpacing)
    }

    var body: some View {
        GeometryReader { geo in
            let n = max(values.count, 1)
            let totalSpacing = barSpacing * CGFloat(max(n - 1, 0))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(n))

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(values.indices, id: \.self) { i in
                        bar(at: i, full: geo.size.height, width: barWidth)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)

                if let nowIndex, n > 1 {
                    nowMarker(at: nowIndex, totalWidth: geo.size.width,
                              barWidth: barWidth, height: geo.size.height)
                }
            }
        }
    }

    private func bar(at i: Int, full: CGFloat, width: CGFloat) -> some View {
        let mm = values[i]
        let h = max(Self.height(forMmPerHour: mm, full: full), 2)
        let isPast = (nowIndex.map { i < $0 } ?? false)
        return Capsule(style: .continuous)
            .fill(RainIntensity.color(forMmPerHour: mm))
            .opacity(isPast ? 0.35 : 1.0)
            .frame(width: width, height: h)
    }

    private func nowMarker(at index: Int,
                           totalWidth: CGFloat,
                           barWidth: CGFloat,
                           height: CGFloat) -> some View {
        let step = barWidth + barSpacing
        let x = CGFloat(index) * step + barWidth / 2
        return Rectangle()
            .fill(Color.owInkPrimary.opacity(0.4))
            .frame(width: 1, height: height)
            .offset(x: x - 0.5)
            .accessibilityHidden(true)
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
