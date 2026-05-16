import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("AppIconImage")
                .resizable()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .accessibilityHidden(true)
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
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .background(Color.owSurface.ignoresSafeArea())
    }
}
