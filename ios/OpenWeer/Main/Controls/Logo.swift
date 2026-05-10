import SwiftUI

struct Logo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.owSun)
                .frame(width: 56, height: 56)
                .offset(x: -16, y: -12)
            Capsule()
                .fill(Color.owSurfaceCard)
                .frame(width: 88, height: 44)
                .offset(x: 6, y: 6)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            HStack(spacing: 4) {
                Capsule().fill(Color.owAccent).frame(width: 4, height: 14)
                Capsule().fill(Color.owAccent).frame(width: 4, height: 14)
                Capsule().fill(Color.owAccent).frame(width: 4, height: 14)
            }
            .offset(x: 6, y: 30)
        }
        .accessibilityHidden(true)
    }
}
