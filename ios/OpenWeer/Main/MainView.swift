import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var clock = FrameClock()
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var detent: SheetDetent = .collapsed
    @State private var chatPresented = false
    @State private var locationService = LocationService.shared

    /// Drag-handle (28) + search bar (~46 with padding) + timeline card (~108) ≈ 192
    private let collapsedSheetHeight: CGFloat = 192

    var body: some View {
        @Bindable var state = appState
        ZStack(alignment: .top) {
            GeometryReader { geo in
                let sheetH = currentSheetHeight(in: geo)
                ZStack {
                    RadarMapView(
                        coordinate: state.coordinate,
                        frame: currentFrame,
                        basemap: BasemapStyle.resolve(for: colorScheme),
                        tileBaseURL: apiBaseURL(),
                        bottomObscuredInset: sheetH
                    )
                    .ignoresSafeArea()
                    LocationDotMarker()
                        .position(x: geo.size.width / 2,
                                  y: (geo.size.height - sheetH) / 2)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ChatButton { chatPresented = true }
                        ThemeToggle()
                        RecenterButton {
                            Task { await recenterToUserLocation() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }
            .ignoresSafeArea(edges: .bottom)

            BottomSheet(
                detent: $detent,
                collapsedHeight: collapsedSheetHeight,
                header: {
                    VStack(spacing: 8) {
                        LocationBar { coord, name in
                            switchTo(coord: coord, name: name)
                        }
                        .padding(.horizontal, 16)
                        timelineCard
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                    }
                },
                bodyContent: { sheetBody }
            )
        }
        .background(Color.owSurface)
        .task {
            await loadFrames()
            await tryUseUserLocationOnLaunch()
            await loadAllData()
        }
        .sheet(isPresented: $chatPresented) {
            AiChatPanel()
                .environment(appState)
        }
        .alert("Fout bij laden",
               isPresented: .constant(loadError != nil),
               presenting: loadError) { _ in
            Button("OK") { loadError = nil }
        } message: { msg in
            Text(msg)
        }
    }

    /// Sheet height (pt) at the current detent. The map uses this as a
    /// bottom contentInset so `setCenter` lands the coord above the sheet,
    /// and the marker is positioned at the matching visible center.
    private func currentSheetHeight(in geo: GeometryProxy) -> CGFloat {
        let total = geo.size.height
        switch detent {
        case .collapsed: return collapsedSheetHeight
        case .medium:    return total * 0.55
        case .expanded:  return total * 0.92
        }
    }

    private var currentFrame: Frame? {
        let frames = appState.frames
        guard !frames.isEmpty else { return nil }
        return frames[max(0, min(frames.count - 1, appState.selectedFrameIndex))]
    }

    @ViewBuilder
    private var sheetBody: some View {
        let state = appState
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                WeatherNowChip(locationName: state.locationName, weather: state.weather)
                    .padding(.top, 8)
                rainCard
                if let weather = state.weather {
                    WeatherNowCard(response: weather)
                }
                if let forecast = state.forecast {
                    ForecastList(response: forecast)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDisabled(detent == .collapsed)
    }

    @ViewBuilder
    private var rainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Regen — komende 2 uur")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Spacer()
                if let rain = appState.rain {
                    Text(headlineText(for: rain))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
            if let rain = appState.rain {
                RainGraph(samples: rain.samples, analysisAt: rain.analysisAt)
                RainLegend()
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 110)
            } else {
                Text("Geen gegevens beschikbaar")
                    .foregroundStyle(Color.owInkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            }
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var timelineCard: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(timeLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Spacer()
                Button {
                    if clock.isPlaying {
                        clock.stop()
                    } else {
                        clock.start(framesCount: state.frames.count) {
                            let next = (state.selectedFrameIndex + 1) % max(state.frames.count, 1)
                            state.selectedFrameIndex = next
                        }
                    }
                } label: {
                    Image(systemName: clock.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.owAccent)
                        .clipShape(Circle())
                }
                .accessibilityLabel(clock.isPlaying ? "Pauze" : "Afspelen")
            }
            TimelineSlider(frames: state.frames,
                           selectedIndex: $state.selectedFrameIndex)
        }
        .padding(14)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var timeLabel: String {
        guard let f = currentFrame else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEE HH:mm"
        let prefix: String
        switch f.kind {
        case .observed: prefix = "Nu"
        case .nowcast:  prefix = "Verwacht"
        case .hourly:   prefix = "Per uur"
        }
        return "\(prefix) · \(formatter.string(from: f.ts))"
    }

    private func headlineText(for rain: RainResponse) -> String {
        let peak = rain.samples.max(by: { $0.mmPerHour < $1.mmPerHour })
        guard let peak, peak.mmPerHour >= 0.1 else {
            return "Droog"
        }
        return String(format: "Piek %.1f mm/u", peak.mmPerHour)
    }

    private func apiBaseURL() -> URL {
        let str = (Bundle.main.object(forInfoDictionaryKey: "OPENWEER_API_BASE") as? String)
            ?? "https://openweer.nl"
        return URL(string: str) ?? URL(string: "https://openweer.nl")!
    }

    private func loadFrames() async {
        do {
            let resp = try await APIClient.shared.frames()
            await MainActor.run {
                appState.frames = resp.frames
                let observed = resp.frames.lastIndex(where: { $0.kind == .observed }) ?? max(0, resp.frames.count - 1)
                appState.selectedFrameIndex = observed
            }
        } catch {
            await MainActor.run { loadError = String(describing: error) }
        }
    }

    /// On app start, if the user has previously granted location, fetch a fresh
    /// fix and update appState. Falls back silently if not authorized.
    private func tryUseUserLocationOnLaunch() async {
        let status = locationService.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        if let coord = await locationService.resolveCurrentLocation() {
            await MainActor.run {
                appState.coordinate = coord
                appState.locationName = locationService.lastPlaceName ?? "Mijn locatie"
            }
        }
    }

    /// Jump the map to an explicit coordinate (search result, preset).
    private func switchTo(coord: CLLocationCoordinate2D, name: String) {
        appState.coordinate = coord
        appState.locationName = name
        Task { await loadAllData() }
    }

    /// Recenter button: ask the user (if needed), fetch a fresh fix, update
    /// the map. If permission denied or fix fails, fall back to Amsterdam.
    private func recenterToUserLocation() async {
        let status = locationService.authorizationStatus
        if status == .notDetermined {
            locationService.requestPermission()
        }
        if let coord = await locationService.resolveCurrentLocation() {
            await MainActor.run {
                appState.coordinate = coord
                appState.locationName = locationService.lastPlaceName ?? "Mijn locatie"
            }
            await loadAllData()
            return
        }
        // Fallback: Amsterdam
        await MainActor.run {
            let amsterdam = KnownLocations.all[0]
            appState.coordinate = amsterdam.coordinate
            appState.locationName = amsterdam.name
        }
        await loadAllData()
    }

    private func loadAllData() async {
        let coord = appState.coordinate
        await MainActor.run { isLoading = true }
        async let rain = APIClient.shared.rain(at: coord)
        async let weather = APIClient.shared.weather(at: coord)
        async let forecast = APIClient.shared.forecast(at: coord)
        do {
            let (r, w, f) = try await (rain, weather, forecast)
            await MainActor.run {
                appState.rain = r
                appState.weather = w
                appState.forecast = f
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = String(describing: error)
                isLoading = false
            }
        }
    }
}

private struct ChatButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.owAccent)
                .frame(width: 44, height: 44)
                .background(Color.owSurfaceCard)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .accessibilityLabel("Stel een vraag aan OpenWeer")
        .accessibilityIdentifier("chat.open")
    }
}
