import SwiftUI

// MARK: - Small

struct RainNowcastSmall: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            Text(entry.location.name)
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .unredacted()

            heroBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            chartBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroBlock: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        return VStack(alignment: .leading, spacing: 0) {
            Text(summary.hero)
                .font(WidgetTheme.hero(size: 30))
                .foregroundStyle(summary.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(summary.detail)
                .font(WidgetTheme.support)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(2)
        }
    }

    private var chartBlock: some View {
        let snapshot = RainWindow.recent(from: entry.rain?.samples ?? [],
                                         now: entry.date)
        return RainBarChart(samples: snapshot.samples, nowIndex: snapshot.nowIndex)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
    }
}

// MARK: - Medium

struct RainNowcastMedium: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            header
            chartBlock
            axis
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.location.name)
                    .font(WidgetTheme.eyebrow)
                    .tracking(0.6)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                    .unredacted()
                Text(summary.hero)
                    .font(WidgetTheme.hero(size: 28))
                    .foregroundStyle(summary.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(summary.detail)
                    .font(WidgetTheme.support)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            countdownPill
        }
    }

    private var countdownPill: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        return VStack(alignment: .trailing, spacing: 0) {
            if let minutes = summary.countdownMinutes {
                Text("\(minutes)")
                    .font(WidgetTheme.hero(size: 26))
                    .foregroundStyle(summary.tint)
                    .monospacedDigit()
                Text("min")
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owInkSecondary)
            } else {
                Text(WidgetFormatting.updatedAt(entry.rain?.analysisAt, now: entry.date))
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
    }

    private var chartBlock: some View {
        let snapshot = RainWindow.standard(from: entry.rain?.samples ?? [],
                                           now: entry.date)
        return RainBarChart(samples: snapshot.samples, nowIndex: snapshot.nowIndex)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
    }

    private var axis: some View {
        let snapshot = RainWindow.standard(from: entry.rain?.samples ?? [],
                                           now: entry.date)
        return RainAxisLabels(samples: snapshot.samples,
                              nowIndex: snapshot.nowIndex,
                              now: entry.date)
            .font(WidgetTheme.meta)
            .foregroundStyle(Color.owInkSecondary)
    }
}

// MARK: - Axis labels with "Nu" marker

/// Relative axis (e.g. "Nu", "+30", "+60", "+120"). Absolute clock times
/// would lie the moment WidgetKit shows a stale entry; minute offsets stay
/// readable regardless of refresh staleness.
struct RainAxisLabels: View {
    let samples: [RainSample]
    let nowIndex: Int?
    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { _, stop in
                Text(label(for: stop))
                    .frame(maxWidth: .infinity, alignment: stop.alignment)
            }
        }
    }

    private struct Stop {
        let sample: RainSample
        let isNow: Bool
        let alignment: Alignment
    }

    private var stops: [Stop] {
        guard samples.count > 1 else { return [] }
        var result: [Stop] = []
        if let first = samples.first {
            result.append(.init(sample: first, isNow: false, alignment: .leading))
        }
        if let idx = nowIndex, idx > 0 && idx < samples.count - 1 {
            result.append(.init(sample: samples[idx], isNow: true, alignment: .center))
        }
        let midIdx = samples.count / 2
        if midIdx != nowIndex {
            result.append(.init(sample: samples[midIdx], isNow: false, alignment: .center))
        }
        if let last = samples.last {
            result.append(.init(sample: last, isNow: false, alignment: .trailing))
        }
        return result
    }

    private func label(for stop: Stop) -> String {
        if stop.isNow { return "Nu" }
        let minutes = Int((stop.sample.validAt.timeIntervalSince(now) / 60).rounded())
        if minutes == 0 { return "Nu" }
        let sign = minutes > 0 ? "+" : "−"
        return "\(sign)\(abs(minutes))"
    }
}
