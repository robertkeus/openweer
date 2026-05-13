import SwiftUI

struct RecenterButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.owAccent)
                .frame(width: 44, height: 44)
                .background(Color.owSurfaceCard)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .accessibilityLabel("Herstel locatie")
    }
}
