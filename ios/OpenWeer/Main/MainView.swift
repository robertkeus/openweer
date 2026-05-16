import SwiftUI
import CoreLocation

struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var clock = FrameClock()
    @State private var loadError: String?
    @State private var detent: SheetDetent = .collapsed
    @State private var chatPresented = false
    @State private var locationService = LocationService.shared
    @State private var pendingPanTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?

    /// Drag-handle (28) + search bar (~46) + timeline card (~108) ≈ 182,
    /// plus the chip row peeking from the body to hint that more is below.
    private let collapsedSheetHeight: CGFloat = 220

    var body: some View {
        @Bindable var state = appState
        ZStack(alignment: .top) {
            GeometryReader { geo in
                let sheetH = currentSheetHeight(in: geo)
                ZStack {
                    RadarMapView(
                        coordinate: state.coordinate,
                        frames: playableFrames,
                        frame: currentFrame,
                        basemap: BasemapStyle.resolve(for: colorScheme),
                        tileBaseURL: apiBaseURL(),
                        bottomObscuredInset: sheetH,
                        onUserCenterChanged: { coord in handleMapPan(to: coord) }
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
                        LocationBar(
                            onPick: { coord, name in
                                switchTo(coord: coord, name: name)
                            },
                            onUseMyLocation: {
                                await recenterToUserLocation()
                            }
                        )
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
            startLoad()
        }
        .onChange(of: appState.forecastHorizon) { oldHorizon, _ in
            // Re-anchor / reclamp the cursor when the visible window changes.
            let priorCount = PlayableFrames
                .filter(appState.frames, horizon: oldHorizon)
                .count
            reclampSelection(previousCount: priorCount)
            clock.stop()
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

    /// Frames currently visible on the slider — filtered by horizon so picking
    /// +2h shows radar nowcast only and longer horizons admit HARMONIE-AROME
    /// hourly forecast frames.
    private var playableFrames: [Frame] {
        PlayableFrames.filter(appState.frames, horizon: appState.forecastHorizon)
    }

    private var currentFrame: Frame? {
        let frames = playableFrames
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
    private var timelineCard: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 10) {
            let playable = playableFrames
            HStack {
                Text(timeLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Spacer()
                Button {
                    if clock.isPlaying {
                        clock.stop()
                    } else {
                        let count = playable.count
                        clock.start(framesCount: count) {
                            let next = (state.selectedFrameIndex + 1) % max(count, 1)
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
                HorizonButton(value: $state.forecastHorizon)
            }
            TimelineSlider(frames: playable,
                           rainSamples: state.rain?.samples ?? [],
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
                anchorSelectionAtNow()
            }
        } catch {
            await MainActor.run { loadError = String(describing: error) }
        }
    }

    /// Pin the slider cursor on the frame closest to wall-clock now within
    /// the currently visible (horizon-filtered) window.
    private func anchorSelectionAtNow() {
        let playable = playableFrames
        guard !playable.isEmpty else { return }
        appState.selectedFrameIndex = PlayableFrames.currentIndex(in: playable)
    }

    /// Keep `selectedFrameIndex` in-bounds when the horizon shrinks; re-anchor
    /// on "now" when it grows.
    private func reclampSelection(previousCount: Int) {
        let playable = playableFrames
        guard !playable.isEmpty else { return }
        if playable.count < previousCount {
            appState.selectedFrameIndex = min(appState.selectedFrameIndex, playable.count - 1)
        } else {
            anchorSelectionAtNow()
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
        pendingPanTask?.cancel()
        pendingPanTask = nil
        appState.coordinate = coord
        appState.locationName = name
        startLoad()
    }

    /// User-driven pan/zoom settled — adopt the new center as the active
    /// location, debounced so a continuous gesture only fires one fetch.
    private func handleMapPan(to coord: CLLocationCoordinate2D) {
        pendingPanTask?.cancel()
        pendingPanTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            appState.coordinate = coord
            appState.locationName = "Locatie zoeken…"
            // Fetch weather data and the reverse-geocoded name in parallel;
            // neither waits on the other.
            startLoad()
            let resolved = await locationService.resolvePlaceName(for: coord)
            if Task.isCancelled { return }
            if let name = resolved {
                appState.locationName = name
            } else {
                appState.locationName = String(format: "%.3f, %.3f",
                                               coord.latitude, coord.longitude)
            }
        }
    }

    /// Recenter button: ask the user (if needed), fetch a fresh fix, update
    /// the map. If permission denied or fix fails, fall back to Amsterdam.
    private func recenterToUserLocation() async {
        pendingPanTask?.cancel()
        pendingPanTask = nil
        let status = locationService.authorizationStatus
        if status == .notDetermined {
            locationService.requestPermission()
        }
        if let coord = await locationService.resolveCurrentLocation() {
            appState.coordinate = coord
            appState.locationName = locationService.lastPlaceName ?? "Mijn locatie"
            startLoad()
            return
        }
        // Fallback: Amsterdam
        let amsterdam = KnownLocations.all[0]
        appState.coordinate = amsterdam.coordinate
        appState.locationName = amsterdam.name
        startLoad()
    }

    /// Cancel any in-flight load and kick off a fresh fan-out. Each endpoint
    /// commits its slice of `appState` independently the moment it resolves
    /// — so the fastest call (usually /api/rain) lands in a few hundred ms
    /// instead of being gated on the slowest (/api/forecast).
    private func startLoad() {
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            await loadAllData()
        }
    }

    private func loadAllData() async {
        let coord = appState.coordinate
        async let rain: Void = loadRain(coord: coord)
        async let weather: Void = loadWeather(coord: coord)
        async let forecast: Void = loadForecast(coord: coord)
        _ = await (rain, weather, forecast)
    }

    @MainActor
    private func loadRain(coord: CLLocationCoordinate2D) async {
        do {
            let r = try await APIClient.shared.rain(at: coord)
            if Task.isCancelled { return }
            appState.rain = r
        } catch where Self.isCancellation(error) {
            return
        } catch {
            if Task.isCancelled { return }
            loadError = String(describing: error)
        }
    }

    @MainActor
    private func loadWeather(coord: CLLocationCoordinate2D) async {
        do {
            let w = try await APIClient.shared.weather(at: coord)
            if Task.isCancelled { return }
            appState.weather = w
        } catch where Self.isCancellation(error) {
            return
        } catch {
            if Task.isCancelled { return }
            loadError = String(describing: error)
        }
    }

    @MainActor
    private func loadForecast(coord: CLLocationCoordinate2D) async {
        do {
            let f = try await APIClient.shared.forecast(at: coord)
            if Task.isCancelled { return }
            appState.forecast = f
        } catch where Self.isCancellation(error) {
            return
        } catch {
            if Task.isCancelled { return }
            loadError = String(describing: error)
        }
    }

    /// Treats both Swift's structured `CancellationError` and URLSession's
    /// `URLError.cancelled` (NSURLErrorCancelled, -999) as silent. The
    /// latter is what we get when `loadTask?.cancel()` aborts an in-flight
    /// fetch — usually because the marker moved before the previous load
    /// finished. Without this guard the alert flashes "Fout bij laden …
    /// Code=-999 'cancelled'" on every fast pan.
    private static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let u = error as? URLError, u.code == .cancelled { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
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
