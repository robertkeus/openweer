import SwiftUI

/// Detail screen for a single day — surfaced on tap from `DailyForecastRow`.
/// Owns the lazy fetch of `HourlyForecastResponse` and renders the header
/// synchronously from `day` so the sheet is never blank.
struct DayDetailSheet: View {
    let day: DailyForecast
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var loadTask: Task<Void, Never>?
    @State private var loadError: String?

    /// Hourly is considered fresh for 10 min after a successful fetch — the
    /// daily forecast cache TTL on the server is 15 min, so this stays under.
    private let freshness: TimeInterval = 10 * 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DayDetailHeader(day: day, slots: slotsForDay)
                    if let error = loadError, slotsForDay.isEmpty {
                        errorBanner(error)
                    }
                    HourlyStripCard(slots: slotsForDay, day: day, isToday: isToday)
                    if !slotsForDay.isEmpty {
                        HourlyRainChart(slots: slotsForDay)
                    } else {
                        HourlyRainChart(slots: slotsForDay)
                            .redacted(reason: .placeholder)
                    }
                    DayDetailStatsGrid(day: day, slots: slotsForDay)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
            .background(Color.owSurface)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                        .foregroundStyle(Color.owAccent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadHourlyIfNeeded() }
        .onDisappear { loadTask?.cancel() }
    }

    private var slotsForDay: [HourlySlot] {
        appState.hourlyForecast?.slots(forDate: day.date) ?? []
    }

    private var isToday: Bool {
        day.date == DayDetailSheet.todayIso()
    }

    private var navigationTitle: String {
        if isToday { return "Vandaag" }
        if day.date == DayDetailSheet.tomorrowIso() { return "Morgen" }
        return formatWeekday(day.date)
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.owAccent)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.owInkPrimary)
            Spacer()
            Button("Opnieuw") {
                loadError = nil
                Task { await loadHourlyIfNeeded(force: true) }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.owAccent)
        }
        .padding(12)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadHourlyIfNeeded(force: Bool = false) async {
        if !force, let loadedAt = appState.hourlyForecastLoadedAt,
           Date().timeIntervalSince(loadedAt) < freshness,
           appState.hourlyForecast != nil {
            return
        }
        loadTask?.cancel()
        let coord = appState.coordinate
        let task = Task { @MainActor in
            do {
                let resp = try await APIClient.shared.hourlyForecast(at: coord)
                if Task.isCancelled { return }
                appState.hourlyForecast = resp
                appState.hourlyForecastLoadedAt = Date()
                loadError = nil
            } catch is CancellationError {
                // ignore
            } catch {
                if !Task.isCancelled {
                    loadError = "Per-uur niet beschikbaar."
                }
            }
        }
        loadTask = task
        await task.value
    }

    private func formatWeekday(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        guard let date = parser.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "nl_NL")
        out.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: date).capitalized
    }

    static func todayIso() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: Date())
    }

    static func tomorrowIso() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: Date().addingTimeInterval(86_400))
    }
}
