import SwiftUI

/// Round button shown next to the play control. Tap opens a native iOS Menu
/// listing the available forecast horizons; selection updates the binding.
/// +2 h is the radar-only nowcast horizon; longer values bring HARMONIE-AROME
/// hourly frames into the slider's window.
struct HorizonButton: View {
    @Binding var value: ForecastHorizon

    var body: some View {
        Menu {
            Picker("Voorspelling-horizon", selection: $value) {
                ForEach(ForecastHorizon.allCases) { h in
                    Text("\(h.hours) uur").tag(h)
                }
            }
        } label: {
            Text("+\(value.hours)u")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
                .frame(minWidth: 32, minHeight: 32)
                .background(Color.owAccent)
                .clipShape(Capsule())
        }
        .accessibilityLabel("Voorspelling-horizon: +\(value.hours) uur. Klik om aan te passen.")
    }
}
