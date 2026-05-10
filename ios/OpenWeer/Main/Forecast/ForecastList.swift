import SwiftUI

struct ForecastList: View {
    let response: ForecastResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("8-daagse verwachting")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Spacer()
                Text(response.source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(response.days.enumerated()), id: \.element.id) { idx, day in
                    DailyForecastRow(day: day)
                    if idx < response.days.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
