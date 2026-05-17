import SwiftUI

// MARK: - Medium

struct RainMapMedium: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            mapBackground
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading) {
                eyebrow
                Spacer()
                statusPill
            }
        }
    }

    private var mapBackground: some View {
        Group {
            if let data = entry.mapImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.owInkSecondary.opacity(0.10)
            }
        }
    }

    private var eyebrow: some View {
        HStack {
            Text(entry.location.name)
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.35), in: Capsule(style: .continuous))
                .unredacted()
            Spacer()
            Text(WidgetFormatting.updatedAt(entry.rain?.analysisAt, now: entry.date))
                .font(WidgetTheme.meta)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.35), in: Capsule(style: .continuous))
        }
    }

    private var statusPill: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        return HStack(spacing: 8) {
            Text(summary.hero)
                .font(WidgetTheme.statement)
                .foregroundStyle(.white)
            if let mins = summary.countdownMinutes {
                Text("\(mins) min")
                    .font(WidgetTheme.meta)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(summary.detail)
                    .font(WidgetTheme.meta)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45), in: Capsule(style: .continuous))
    }
}

// MARK: - Large

struct RainMapLarge: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            header
            mapBlock
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            chart
        }
    }

    private var header: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.location.name)
                    .font(WidgetTheme.eyebrow)
                    .tracking(0.6)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                    .unredacted()
                Text(summary.hero)
                    .font(WidgetTheme.hero(size: 24))
                    .foregroundStyle(summary.tint)
                    .lineLimit(1)
                Text(summary.detail)
                    .font(WidgetTheme.support)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if let mins = summary.countdownMinutes {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(mins)")
                        .font(WidgetTheme.hero(size: 26))
                        .foregroundStyle(summary.tint)
                        .monospacedDigit()
                    Text("min")
                        .font(WidgetTheme.meta)
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
        }
    }

    private var mapBlock: some View {
        ZStack {
            if let data = entry.mapImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.owInkSecondary.opacity(0.10)
            }
        }
    }

    private var chart: some View {
        let snap = RainWindow.standard(from: entry.rain?.samples ?? [],
                                       now: entry.date)
        return VStack(spacing: 4) {
            RainBarChart(samples: snap.samples, nowIndex: snap.nowIndex)
                .frame(height: 36)
            RainAxisLabels(samples: snap.samples,
                           nowIndex: snap.nowIndex,
                           now: entry.date)
                .font(WidgetTheme.meta)
                .foregroundStyle(Color.owInkSecondary)
        }
    }
}
