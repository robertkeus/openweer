import SwiftUI

struct TimelineSlider: View {
    let frames: [Frame]
    /// Point-rain samples used to size the intensity bars. Optional — when
    /// missing or sparse, bars fall back to a baseline height.
    var rainSamples: [RainSample] = []
    @Binding var selectedIndex: Int

    @State private var dragIndex: Int?
    @State private var feedbackTrigger = 0

    var body: some View {
        GeometryReader { geo in
            let count = max(frames.count, 1)
            let stepWidth = geo.size.width / CGFloat(count)
            let bars = buildIntensityBars(frames: frames, samples: rainSamples)
            ZStack(alignment: .leading) {
                // Intensity bars — height ∝ mm/h, color by intensity. HARMONIE
                // bars carry a diagonal-hatch overlay and reduced opacity so
                // the source is unambiguous at a glance.
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        IntensityBar(
                            heightFraction: bar.heightFraction,
                            color: bar.color,
                            opacity: bar.opacity,
                            hatched: bar.hatched
                        )
                    }
                }
                .frame(height: 22, alignment: .bottom)

                // Baseline rail sits on top of the bars' bottom edge.
                Capsule()
                    .fill(Color.owInkSecondary.opacity(0.15))
                    .frame(height: 1)
                    .offset(y: 22)

                // Cursor — thick line + handle at the bottom rail.
                Rectangle()
                    .fill(Color.owAccent)
                    .frame(width: 2, height: 22)
                    .position(x: stepWidth * (CGFloat(currentIndex) + 0.5), y: 11)
                Circle()
                    .fill(Color.owAccent)
                    .frame(width: 10, height: 10)
                    .position(x: stepWidth * (CGFloat(currentIndex) + 0.5), y: 22)
                    .animation(.snappy(duration: 0.15), value: currentIndex)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let i = max(0, min(frames.count - 1,
                                           Int(v.location.x / stepWidth)))
                        if i != dragIndex {
                            dragIndex = i
                            selectedIndex = i
                            feedbackTrigger &+= 1
                        }
                    }
                    .onEnded { _ in dragIndex = nil }
            )
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tijdlijn")
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: if currentIndex < frames.count - 1 { selectedIndex = currentIndex + 1 }
                case .decrement: if currentIndex > 0 { selectedIndex = currentIndex - 1 }
                @unknown default: break
                }
                feedbackTrigger &+= 1
            }
        }
        .frame(height: 28)
    }

    private var currentIndex: Int {
        max(0, min(frames.count - 1, selectedIndex))
    }

    private var accessibilityValue: String {
        guard frames.indices.contains(currentIndex) else { return "" }
        let f = frames[currentIndex]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "HH:mm"
        let source: String
        switch f.kind {
        case .observed: source = "waarneming"
        case .nowcast:  source = "voorspelling (radar)"
        case .hourly:   source = "voorspelling (HARMONIE-model)"
        }
        return "\(formatter.string(from: f.ts)), \(source)"
    }
}

// MARK: - Bars

private struct IntensityBar: View {
    let heightFraction: CGFloat  // 0..1
    let color: Color
    let opacity: Double
    let hatched: Bool

    var body: some View {
        GeometryReader { proxy in
            let h = max(3, proxy.size.height * heightFraction)
            VStack {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color)
                    .overlay {
                        if hatched {
                            DiagonalHatch()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        }
                    }
                    .frame(height: h)
                    .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DiagonalHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let spacing: CGFloat = 4
        var x: CGFloat = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height))
            p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        return p
    }
}

private struct IntensityBarSpec {
    let heightFraction: CGFloat
    let color: Color
    let opacity: Double
    let hatched: Bool
}

private func buildIntensityBars(
    frames: [Frame],
    samples: [RainSample]
) -> [IntensityBarSpec] {
    // Bucket samples to 10-min keys, keep the max mm/h per bucket.
    let tenMin: TimeInterval = 10 * 60
    var buckets: [Int: Double] = [:]
    for s in samples {
        let key = Int(s.validAt.timeIntervalSince1970 / tenMin)
        buckets[key] = max(buckets[key] ?? 0, s.mmPerHour)
    }
    let yMax = max(2.0, buckets.values.max() ?? 0)

    return frames.map { f in
        let key = Int(f.ts.timeIntervalSince1970 / tenMin)
        let mm = buckets[key]
        let hasData = mm != nil
        let intensity = mm ?? 0
        let heightFraction: CGFloat = hasData
            ? max(0.06, CGFloat(min(intensity, yMax) / yMax))
            : 0.06
        let isHourly = f.kind == .hourly
        return IntensityBarSpec(
            heightFraction: heightFraction,
            color: hasData ? colorForRate(intensity) : Color.owInkSecondary.opacity(0.4),
            opacity: !hasData ? 0.35 : (isHourly ? 0.55 : 1.0),
            hatched: hasData && isHourly
        )
    }
}

private func colorForRate(_ mm: Double) -> Color {
    // Mirrors the web colormap stops + Timeline.tsx `colorFor`.
    if mm < 0.1 { return Color.owInkSecondary.opacity(0.4) }
    if mm < 0.5 { return Color(red: 155/255, green: 195/255, blue: 241/255) }
    if mm < 1.0 { return Color(red: 92/255,  green: 142/255, blue: 232/255) }
    if mm < 2.0 { return Color(red: 31/255,  green: 93/255,  blue: 208/255) }
    if mm < 5.0 { return Color(red: 45/255,  green: 184/255, blue: 74/255) }
    if mm < 10  { return Color(red: 245/255, green: 213/255, blue: 45/255) }
    if mm < 20  { return Color(red: 245/255, green: 159/255, blue: 45/255) }
    if mm < 50  { return Color(red: 230/255, green: 53/255,  blue: 61/255) }
    return Color(red: 192/255, green: 38/255, blue: 211/255)
}
