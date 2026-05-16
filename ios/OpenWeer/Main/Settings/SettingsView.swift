import SwiftUI

/// Single sheet exposing theme + language + favorites management.
/// Reached from the overflow menu in `ThemeToggle`.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showingFavorites = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Meldingen") {
                    Button {
                        showingFavorites = true
                    } label: {
                        HStack {
                            Label("Favorieten", systemImage: "star.fill")
                            Spacer()
                            Text("\(FavoritesStore.shared.favorites.count)")
                                .foregroundStyle(Color.owInkSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.owInkSecondary)
                        }
                    }
                    .accessibilityIdentifier("settings.favorites")
                }
                Section("Weergave") {
                    Picker("Thema", selection: bindingTheme()) {
                        Text("Systeem").tag(ThemePreference.system)
                        Text("Licht").tag(ThemePreference.light)
                        Text("Donker").tag(ThemePreference.dark)
                    }
                    Picker("Taal", selection: bindingLanguage()) {
                        Text("Nederlands").tag(LanguagePreference.nl)
                        Text("English").tag(LanguagePreference.en)
                    }
                }
            }
            .navigationTitle("Instellingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                        .foregroundStyle(Color.owAccent)
                }
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesListView()
            }
        }
    }

    private func bindingTheme() -> Binding<ThemePreference> {
        Binding(get: { appState.theme }, set: { appState.theme = $0 })
    }

    private func bindingLanguage() -> Binding<LanguagePreference> {
        Binding(get: { appState.language }, set: { appState.language = $0 })
    }
}
