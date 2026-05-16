import SwiftUI
import CoreLocation

/// Search-and-jump UI shown above the timeline. Tapping the field opens
/// a sheet with: a "use my location" action, debounced Nominatim search,
/// and a grid of preset Dutch cities.
struct LocationBar: View {
    @Environment(AppState.self) private var appState
    let onPick: (CLLocationCoordinate2D, String) -> Void
    let onUseMyLocation: () async -> Void

    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.owInkSecondary)
                Text(appState.locationName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.owInkPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.owInkSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.owSurfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
        }
        .accessibilityIdentifier("location.search.open")
        .sheet(isPresented: $presented) {
            LocationSearchSheet(
                onPick: { coord, name in
                    onPick(coord, name)
                    presented = false
                },
                onUseMyLocation: {
                    Task {
                        await onUseMyLocation()
                        presented = false
                    }
                }
            )
            .environment(appState)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct LocationSearchSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D, String) -> Void
    let onUseMyLocation: () -> Void

    @State private var query: String = ""
    @State private var results: [NominatimResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.owSurface.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                searchField
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if query.isEmpty {
                            useMyLocationButton
                            cityGrid
                        } else {
                            resultsList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchFocused = true
            }
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Text("Locatie")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.owInkSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.owSurfaceCard)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Sluiten")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Search field

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.owInkSecondary)
            TextField("Zoek een plaats…", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .focused($searchFocused)
                .accessibilityIdentifier("location.search.field")
                .onChange(of: query) { _, newValue in
                    scheduleSearch(for: newValue)
                }
                .onSubmit { scheduleSearch(for: query, immediate: true) }
            if searching {
                ProgressView().scaleEffect(0.7)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - "Use my location"

    @ViewBuilder
    private var useMyLocationButton: some View {
        Button(action: { onUseMyLocation() }) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.owAccent)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mijn locatie")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.owInkPrimary)
                    Text("Gebruik GPS voor het weer hier")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.owInkSecondary)
            }
            .padding(14)
            .background(Color.owSurfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityIdentifier("location.use_mine")
    }

    // MARK: - City grid

    @ViewBuilder
    private var cityGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Steden")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.owInkSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.leading, 4)

            let cols = [GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(KnownLocations.all) { loc in
                    Button(action: { onPick(loc.coordinate, loc.name) }) {
                        HStack(spacing: 10) {
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.owAccent)
                            Text(loc.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.owInkPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.owSurfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12,
                                                    style: .continuous))
                    }
                    .accessibilityIdentifier("location.preset.\(loc.slug)")
                }
            }
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if results.isEmpty && !searching {
                emptyResults
            } else if !results.isEmpty {
                Text("Resultaten")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.owInkSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.leading, 4)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { idx, r in
                        Button(action: { onPick(r.coordinate, r.shortName) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.owAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.shortName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.owInkPrimary)
                                        .lineLimit(1)
                                    Text(secondary(for: r))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.owInkSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.owInkSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .accessibilityIdentifier("location.search.result")
                        if idx < results.count - 1 {
                            Divider().opacity(0.4).padding(.leading, 50)
                        }
                    }
                }
                .background(Color.owSurfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var emptyResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.owInkSecondary)
                .padding(.top, 24)
            Text("Niets gevonden")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
            Text("Probeer een andere zoekopdracht in Nederland.")
                .font(.system(size: 13))
                .foregroundStyle(Color.owInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    /// Trim "display_name" to a short locality + region.
    private func secondary(for r: NominatimResult) -> String {
        let parts = r.displayName
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        // Drop the first segment (matches shortName) and the last "Nederland".
        let middle = parts.dropFirst().filter { !$0.lowercased().contains("nederland") }
        if middle.isEmpty { return "Nederland" }
        return middle.prefix(2).joined(separator: " · ")
    }

    private func scheduleSearch(for text: String, immediate: Bool = false) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            searching = false
            return
        }
        searching = true
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(280))
                if Task.isCancelled { return }
            }
            do {
                let r = try await NominatimClient().search(trimmed)
                if Task.isCancelled { return }
                results = r
            } catch {
                if Task.isCancelled { return }
                results = []
            }
            searching = false
        }
    }
}
