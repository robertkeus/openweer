import SwiftUI

/// SwiftUI marker overlaid on the MapLibre view at the projected screen
/// position of the active coordinate. Pulses gently so it's easy to spot.
struct LocationDotMarker: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.owAccent.opacity(0.20))
                .frame(width: 56, height: 56)
                .scaleEffect(pulse ? 1.0 : 0.6)
                .opacity(pulse ? 0 : 0.7)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false),
                           value: pulse)
            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            Circle()
                .fill(Color.owAccent)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}
