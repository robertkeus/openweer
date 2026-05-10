import SwiftUI
import CoreLocation

/// Search-and-jump UI shown above the timeline. A tap on the search field
/// expands a sheet with: text input, debounced Nominatim results, and a row
/// of preset Dutch cities.
struct LocationBar: View {
    @Environment(AppState.self) private var appState
    let onPick: (CLLocationCoordinate2D, String) -> Void

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
            LocationSearchSheet(onPick: { coord, name in
                onPick(coord, name)
                presented = false
            })
            .environment(appState)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct LocationSearchSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D, String) -> Void

    @State private var query: String = ""
    @State private var results: [NominatimResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                searchField
                if !query.isEmpty {
                    resultList
                } else {
                    presetList
                }
            }
            .background(Color.owSurface)
            .navigationTitle("Locatie kiezen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.owInkSecondary)
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Sluiten")
                }
            }
        }
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.owInkSecondary)
            TextField("Zoek een plaats in Nederland", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .accessibilityIdentifier("location.search.field")
                .onChange(of: query) { _, newValue in
                    scheduleSearch(for: newValue)
                }
                .onSubmit { scheduleSearch(for: query, immediate: true) }
            if searching {
                ProgressView().scaleEffect(0.7)
            } else if !query.isEmpty {
                Button(action: { query = ""; results = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var resultList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if results.isEmpty && !searching {
                    Text("Geen resultaten")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                        .padding(.top, 24)
                } else {
                    ForEach(results) { r in
                        Button(action: { onPick(r.coordinate, r.shortName) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.shortName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.owInkPrimary)
                                Text(r.displayName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.owInkSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .accessibilityIdentifier("location.search.result")
                        Divider().opacity(0.4).padding(.leading, 16)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var presetList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Snel naar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.owInkSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KnownLocations.all) { loc in
                        Button(action: { onPick(loc.coordinate, loc.name) }) {
                            Text(loc.name)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.owSurfaceCard)
                                .foregroundStyle(Color.owInkPrimary)
                                .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("location.preset.\(loc.slug)")
                    }
                }
                .padding(.horizontal, 16)
            }
            Spacer(minLength: 24)
        }
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
