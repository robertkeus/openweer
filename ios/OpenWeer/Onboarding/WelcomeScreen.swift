import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 32) {
            Spacer()
            Logo()
                .frame(width: 140, height: 140)
            VStack(spacing: 12) {
                Text("welcome.title", bundle: .main)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkPrimary)
                Text("welcome.subtitle", bundle: .main)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkSecondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 16) {
                Button(action: onContinue) {
                    Text("welcome.cta", bundle: .main)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.owAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("welcome.cta")
                .accessibilityLabel("welcome-cta")

                Picker("language", selection: $state.language) {
                    Text("Nederlands").tag(LanguagePreference.nl)
                    Text("English").tag(LanguagePreference.en)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .background(Color.owSurface.ignoresSafeArea())
    }
}
