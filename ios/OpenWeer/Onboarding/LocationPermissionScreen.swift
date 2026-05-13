import SwiftUI
import CoreLocation

struct LocationPermissionScreen: View {
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState
    @State private var locationService = LocationService.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "location.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.owAccent)
            VStack(spacing: 12) {
                Text("location.title", bundle: .main)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkPrimary)
                Text("location.body", bundle: .main)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkSecondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    locationService.requestPermission()
                    Task {
                        if let coord = await locationService.resolveCurrentLocation() {
                            appState.coordinate = coord
                            appState.locationName = locationService.lastPlaceName ?? "Mijn locatie"
                        }
                        onContinue()
                    }
                } label: {
                    Text("location.allow", bundle: .main)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.owAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("location.allow")
                Button(action: onContinue) {
                    Text("location.skip", bundle: .main)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.owInkSecondary)
                }
                .accessibilityIdentifier("location.skip")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .background(Color.owSurface.ignoresSafeArea())
    }
}
