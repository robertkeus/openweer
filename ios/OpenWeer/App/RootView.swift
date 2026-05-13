import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(AppState.self) private var appState

    var body: some View {
        if hasOnboarded {
            MainView()
        } else {
            OnboardingFlow(onComplete: {
                hasOnboarded = true
            })
        }
    }
}
