import SwiftUI

struct TimelineSlider: View {
    let frames: [Frame]
    @Binding var selectedIndex: Int

    @State private var dragIndex: Int?
    @State private var feedbackTrigger = 0

    var body: some View {
        GeometryReader { geo in
            let count = max(frames.count, 1)
            let stepWidth = geo.size.width / CGFloat(count)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.owInkSecondary.opacity(0.15))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.owAccent)
                    .frame(width: stepWidth * CGFloat(currentIndex + 1), height: 4)
                ForEach(frames.indices, id: \.self) { i in
                    let kind = frames[i].kind
                    Circle()
                        .fill(kind == .observed ? Color.owAccent : Color.owSun)
                        .frame(width: i == currentIndex ? 12 : 6,
                               height: i == currentIndex ? 12 : 6)
                        .position(x: stepWidth * (CGFloat(i) + 0.5),
                                  y: 2)
                        .animation(.snappy(duration: 0.15), value: currentIndex)
                }
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let i = max(0, min(frames.count - 1,
                                           Int(v.location.x / stepWidth)))
                        if i != dragIndex {
                            dragIndex = i
                            selectedIndex = i
                            feedbackTrigger &+= 1
                        }
                    }
                    .onEnded { _ in dragIndex = nil }
            )
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tijdlijn")
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: if currentIndex < frames.count - 1 { selectedIndex = currentIndex + 1 }
                case .decrement: if currentIndex > 0 { selectedIndex = currentIndex - 1 }
                @unknown default: break
                }
                feedbackTrigger &+= 1
            }
        }
        .frame(height: 24)
    }

    private var currentIndex: Int {
        max(0, min(frames.count - 1, selectedIndex))
    }

    private var accessibilityValue: String {
        guard frames.indices.contains(currentIndex) else { return "" }
        let f = frames[currentIndex]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: f.ts)), \(f.kind.rawValue)"
    }
}
