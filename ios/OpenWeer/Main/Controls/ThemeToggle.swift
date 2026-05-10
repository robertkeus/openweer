import SwiftUI

/// Small floating button that cycles through System → Light → Dark.
/// Persists via AppState which writes to UserDefaults.
struct ThemeToggle: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            Picker(selection: bindingTheme(), label: EmptyView()) {
                Label("Systeem", systemImage: "circle.lefthalf.filled")
                    .tag(ThemePreference.system)
                Label("Licht", systemImage: "sun.max.fill")
                    .tag(ThemePreference.light)
                Label("Donker", systemImage: "moon.fill")
                    .tag(ThemePreference.dark)
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.owAccent)
                .frame(width: 44, height: 44)
                .background(Color.owSurfaceCard)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .accessibilityLabel("Thema instellen")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("theme.toggle")
    }

    private func bindingTheme() -> Binding<ThemePreference> {
        Binding(
            get: { appState.theme },
            set: { appState.theme = $0 }
        )
    }

    private var iconName: String {
        switch appState.theme {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private var accessibilityValue: String {
        switch appState.theme {
        case .system: return "Systeem"
        case .light:  return "Licht"
        case .dark:   return "Donker"
        }
    }
}
