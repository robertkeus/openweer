import SwiftUI

/// Single sheet exposing the user-facing preferences:
/// notifications (favorites + rain push toggle), appearance, about + version,
/// and legal links to openweer.nl.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showingFavorites = false
    @State private var safariURL: SafariLink?
    @State private var showDeniedAlert = false
    @State private var pushBusy = false

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                appearanceSection
                aboutSection
                legalSection
            }
            .navigationTitle(Text("settings.title", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("settings.done", bundle: .main)
                    }
                    .foregroundStyle(Color.owAccent)
                }
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesListView()
            }
            .sheet(item: $safariURL) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
            .alert(
                Text("settings.push.alert_denied_title", bundle: .main),
                isPresented: $showDeniedAlert
            ) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("settings.push.alert_open_settings", bundle: .main)
                }
                Button(role: .cancel) {
                } label: {
                    Text("settings.push.cancel", bundle: .main)
                }
            } message: {
                Text("settings.push.alert_denied_body", bundle: .main)
            }
        }
    }

    // MARK: - Sections

    private var notificationsSection: some View {
        Section(header: Text("settings.section.notifications", bundle: .main)) {
            Button {
                showingFavorites = true
            } label: {
                HStack {
                    Label {
                        Text("settings.favorites", bundle: .main)
                    } icon: {
                        Image(systemName: "star.fill")
                    }
                    Spacer()
                    Text("\(FavoritesStore.shared.favorites.count)")
                        .foregroundStyle(Color.owInkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
            .accessibilityIdentifier("settings.favorites")

            Toggle(isOn: pushBinding()) {
                Label {
                    Text("settings.push.toggle", bundle: .main)
                } icon: {
                    Image(systemName: "bell.badge.fill")
                }
            }
            .tint(Color.owAccent)
            .disabled(pushBusy)
            .accessibilityIdentifier("settings.push.toggle")

            if appState.pushEnabled && FavoritesStore.shared.favorites.isEmpty {
                Text("settings.push.hint_no_favorites", bundle: .main)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
    }

    private var appearanceSection: some View {
        Section(header: Text("settings.section.appearance", bundle: .main)) {
            Picker(selection: bindingTheme()) {
                Text("settings.theme.system", bundle: .main).tag(ThemePreference.system)
                Text("settings.theme.light", bundle: .main).tag(ThemePreference.light)
                Text("settings.theme.dark", bundle: .main).tag(ThemePreference.dark)
            } label: {
                Text("settings.appearance.theme", bundle: .main)
            }

            Picker(selection: bindingLanguage()) {
                Text("settings.language.dutch", bundle: .main).tag(LanguagePreference.nl)
                Text("settings.language.english", bundle: .main).tag(LanguagePreference.en)
            } label: {
                Text("settings.appearance.language", bundle: .main)
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("settings.section.about", bundle: .main)) {
            NavigationLink {
                AboutBuildView()
            } label: {
                Label {
                    Text("settings.about.how_built", bundle: .main)
                } icon: {
                    Image(systemName: "hammer.fill")
                }
            }

            Button {
                if let url = URL(string: "https://www.linkedin.com/in/robertkeus/") {
                    safariURL = SafariLink(url: url)
                }
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.about.author", bundle: .main)
                                .foregroundStyle(Color.owInkPrimary)
                            Text("settings.about.author_subtitle", bundle: .main)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.owInkSecondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }

            HStack {
                Label {
                    Text("settings.about.version", bundle: .main)
                } icon: {
                    Image(systemName: "info.circle")
                }
                Spacer()
                Text(versionString)
                    .foregroundStyle(Color.owInkSecondary)
                    .monospacedDigit()
            }
        }
    }

    private var legalSection: some View {
        Section(header: Text("settings.section.legal", bundle: .main)) {
            Button {
                if let url = URL(string: "https://openweer.nl/privacy") {
                    safariURL = SafariLink(url: url)
                }
            } label: {
                legalRow(label: "settings.legal.privacy", icon: "hand.raised.fill")
            }
            Button {
                if let url = URL(string: "https://openweer.nl/terms") {
                    safariURL = SafariLink(url: url)
                }
            } label: {
                legalRow(label: "settings.legal.terms", icon: "doc.text.fill")
            }
        }
    }

    @ViewBuilder
    private func legalRow(label: String.LocalizationValue, icon: String) -> some View {
        HStack {
            Label {
                Text(String(localized: label, bundle: .main))
                    .foregroundStyle(Color.owInkPrimary)
            } icon: {
                Image(systemName: icon)
            }
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.owInkSecondary)
        }
    }

    // MARK: - Bindings

    private func bindingTheme() -> Binding<ThemePreference> {
        Binding(get: { appState.theme }, set: { appState.theme = $0 })
    }

    private func bindingLanguage() -> Binding<LanguagePreference> {
        Binding(get: { appState.language }, set: { appState.language = $0 })
    }

    /// Custom binding so we can run async side effects when the user flips
    /// the push toggle: enable goes through `PushService.enableFromSettings`,
    /// disable calls `unsubscribe()` so the backend stops pushing.
    private func pushBinding() -> Binding<Bool> {
        Binding(
            get: { appState.pushEnabled },
            set: { newValue in
                if newValue {
                    pushBusy = true
                    Task {
                        let result = await PushService.shared.enableFromSettings()
                        await MainActor.run {
                            switch result {
                            case .enabled:
                                appState.pushEnabled = true
                            case .needsSystemSettings:
                                showDeniedAlert = true
                                appState.pushEnabled = false
                            case .denied:
                                appState.pushEnabled = false
                            }
                            pushBusy = false
                        }
                    }
                } else {
                    appState.pushEnabled = false
                    Task {
                        await PushService.shared.unsubscribe()
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

/// Identifiable wrapper so we can drive `.sheet(item:)` from a URL.
private struct SafariLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
