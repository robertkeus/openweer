import SwiftUI

/// Reuses the existing `LocationSearchSheet` UI to pick a place, then
/// commits it as a new `Favorite` with default alert prefs. Keeping
/// add/search in one flow means there's exactly one search UI in the app.
struct AddFavoriteFromSearch: View {
    let onAdd: (Favorite) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LocationSearchSheet(
            onPick: { coord, name in
                onAdd(Favorite(label: name, coordinate: coord, alertPrefs: .default))
                dismiss()
            },
            onUseMyLocation: {
                Task {
                    let service = LocationService.shared
                    if let coord = await service.resolveCurrentLocation() {
                        let label = service.lastPlaceName ?? "Mijn locatie"
                        onAdd(Favorite(label: label, coordinate: coord, alertPrefs: .default))
                    }
                    dismiss()
                }
            }
        )
    }
}
