import SwiftUI

/// Edit a favorite's label and alert preferences.
///
/// Coordinates are read-only here; to "move" a favorite the user deletes
/// it and re-adds via search. That keeps the data model simple and avoids
/// shipping a mini-map.
struct FavoriteEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Favorite
    @State private var quietHoursEnabled: Bool

    let onSave: (Favorite) -> Void
    let onCancel: () -> Void

    init(
        favorite: Favorite,
        onSave: @escaping (Favorite) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = State(initialValue: favorite)
        self._quietHoursEnabled = State(
            initialValue: favorite.alertPrefs.quietHoursStart != nil
                && favorite.alertPrefs.quietHoursEnd != nil
        )
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Naam") {
                    TextField("Label", text: $draft.label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("favorite.edit.label")
                }
                Section("Wanneer waarschuwen") {
                    Picker("Lead time", selection: bindingLeadTime()) {
                        Text("15 min").tag(FavoriteLeadTime.fifteen)
                        Text("30 min").tag(FavoriteLeadTime.thirty)
                        Text("60 min").tag(FavoriteLeadTime.sixty)
                    }
                    .pickerStyle(.segmented)

                    Picker("Drempel", selection: bindingThreshold()) {
                        Text("Licht").tag(FavoriteIntensity.light)
                        Text("Matig").tag(FavoriteIntensity.moderate)
                        Text("Zwaar").tag(FavoriteIntensity.heavy)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Stille uren") {
                    Toggle("Niet storen", isOn: $quietHoursEnabled)
                        .onChange(of: quietHoursEnabled) { _, enabled in
                            if enabled {
                                if draft.alertPrefs.quietHoursStart == nil {
                                    draft.alertPrefs.quietHoursStart = 22
                                    draft.alertPrefs.quietHoursEnd = 7
                                }
                            } else {
                                draft.alertPrefs.quietHoursStart = nil
                                draft.alertPrefs.quietHoursEnd = nil
                            }
                        }
                    if quietHoursEnabled {
                        Stepper(
                            "Van \(draft.alertPrefs.quietHoursStart ?? 22):00",
                            value: bindingQuietStart(),
                            in: 0...23
                        )
                        Stepper(
                            "Tot \(draft.alertPrefs.quietHoursEnd ?? 7):00",
                            value: bindingQuietEnd(),
                            in: 0...23
                        )
                    }
                }
            }
            .navigationTitle("Bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleer", action: onCancel)
                        .foregroundStyle(Color.owInkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bewaar") {
                        onSave(draft)
                    }
                    .disabled(draft.label.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(Color.owAccent)
                    .accessibilityIdentifier("favorite.edit.save")
                }
            }
        }
    }

    private func bindingLeadTime() -> Binding<FavoriteLeadTime> {
        Binding(
            get: { draft.alertPrefs.leadTime },
            set: { draft.alertPrefs.leadTime = $0 }
        )
    }

    private func bindingThreshold() -> Binding<FavoriteIntensity> {
        Binding(
            get: { draft.alertPrefs.threshold },
            set: { draft.alertPrefs.threshold = $0 }
        )
    }

    private func bindingQuietStart() -> Binding<Int> {
        Binding(
            get: { draft.alertPrefs.quietHoursStart ?? 22 },
            set: { draft.alertPrefs.quietHoursStart = $0 }
        )
    }

    private func bindingQuietEnd() -> Binding<Int> {
        Binding(
            get: { draft.alertPrefs.quietHoursEnd ?? 7 },
            set: { draft.alertPrefs.quietHoursEnd = $0 }
        )
    }
}
