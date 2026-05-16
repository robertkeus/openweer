import SwiftUI

struct ForecastList: View {
    let response: ForecastResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Komende dagen")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.owInkSecondary)

            VStack(spacing: 0) {
                ForEach(Array(response.days.enumerated()), id: \.element.id) { idx, day in
                    DailyForecastRow(day: day, index: idx)
                    if idx < response.days.count - 1 {
                        Divider()
                            .background(Color.owInkSecondary.opacity(0.15))
                    }
                }
            }
            .background(Color.owSurfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.owInkSecondary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
