import SwiftUI

struct OnboardingFlow: View {
    let onComplete: () -> Void

    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            WelcomeScreen(onContinue: { page = 1 })
                .tag(0)
            LocationPermissionScreen(onContinue: { page = 2 })
                .tag(1)
            NotificationsScreen(onContinue: onComplete)
                .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
