import SwiftUI

/// Floating overflow button. Exposes the theme picker (legacy behaviour)
/// plus an entry into the new Settings sheet, which is where favorites
/// for rain push notifications live.
struct ThemeToggle: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false

    var body: some View {
        Menu {
            Button {
                showingSettings = true
            } label: {
                Label("Instellingen", systemImage: "gearshape")
            }
            .accessibilityIdentifier("settings.open")

            Picker(selection: bindingTheme(), label: EmptyView()) {
                Label("Systeem", systemImage: "circle.lefthalf.filled")
                    .tag(ThemePreference.system)
                Label("Licht", systemImage: "sun.max.fill")
                    .tag(ThemePreference.light)
                Label("Donker", systemImage: "moon.fill")
                    .tag(ThemePreference.dark)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.owAccent)
                .frame(width: 44, height: 44)
                .background(Color.owSurfaceCard)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .accessibilityLabel("Menu")
        .accessibilityIdentifier("theme.toggle")
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appState)
        }
    }

    private func bindingTheme() -> Binding<ThemePreference> {
        Binding(
            get: { appState.theme },
            set: { appState.theme = $0 }
        )
    }
}
