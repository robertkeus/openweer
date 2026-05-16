import SwiftUI

struct NotificationsScreen: View {
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ConditionGlyph(kind: .rain, size: 96)
            VStack(spacing: 12) {
                Text("push.title", bundle: .main)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkPrimary)
                Text("push.body", bundle: .main)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.owInkSecondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    Task {
                        // requestAuthorizationAndRegister triggers
                        // didRegisterForRemoteNotifications → PushService.handleRegistered,
                        // which itself registers the device + syncs favorites with the
                        // backend. No more imperative POST from this screen.
                        _ = await PushService.shared.requestAuthorizationAndRegister()
                        onContinue()
                    }
                } label: {
                    Text("push.allow", bundle: .main)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.owAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("push.allow")
                Button(action: onContinue) {
                    Text("push.skip", bundle: .main)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.owInkSecondary)
                }
                .accessibilityIdentifier("push.skip")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 56)
        }
        .background(Color.owSurface.ignoresSafeArea())
    }
}
