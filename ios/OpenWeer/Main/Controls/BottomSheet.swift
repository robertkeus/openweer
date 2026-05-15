import SwiftUI

enum SheetDetent: CaseIterable {
    case collapsed
    case medium
    case expanded

    /// Fraction of available height occupied by the sheet at this detent.
    func fraction(forCollapsedHeight collapsedPoints: CGFloat,
                  totalHeight: CGFloat,
                  topInset: CGFloat) -> CGFloat {
        switch self {
        case .collapsed: return min(0.95, collapsedPoints / totalHeight)
        case .medium:    return 0.55
        // Fully cover the map at the expanded detent. The background also
        // ignores the top safe area, so the status-bar strip is filled too.
        case .expanded:  return 1.0
        }
    }
}

/// A persistent, drag-to-resize bottom sheet that always remains attached
/// to the bottom of the screen. Three snap points: collapsed → medium → expanded.
/// `header` is always visible (drag handle, plus any pinned content like a timeline).
/// `body` is the scrollable content shown when there's room.
struct BottomSheet<Header: View, Body: View>: View {
    @Binding var detent: SheetDetent
    let collapsedHeight: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let bodyContent: () -> Body

    @State private var dragTranslation: CGFloat = 0
    @State private var snapFeedback = 0

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.height
            let topInset = geo.safeAreaInsets.top
            let h = sheetHeight(in: geo, total: total, topInset: topInset)

            VStack(spacing: 0) {
                // Drag-handle row: a wide touch target dedicated to resizing
                // the sheet. Lives above the header so it never overlaps
                // interactive content (slider, buttons).
                ZStack {
                    Color.owSurface
                    Capsule()
                        .fill(Color.owInkSecondary.opacity(0.35))
                        .frame(width: 44, height: 5)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .onTapGesture { cycleDetent() }
                .gesture(dragGesture(total: total, topInset: topInset))
                .accessibilityElement()
                .accessibilityLabel("Sleep of tik om paneel te verbergen of tonen")
                .accessibilityHint("Drie standen: ingeklapt, half, volledig")
                .accessibilityIdentifier("sheet.handle")

                header()
                bodyContent()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: h, alignment: .top)
            .background(
                Color.owSurface
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 0, bottomTrailing: 0, topTrailing: 18),
                            style: .continuous
                        )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
                    // Extend the surface behind both the status bar (so the
                    // fully-expanded sheet truly covers the map) and the
                    // home indicator strip.
                    .ignoresSafeArea(edges: [.top, .bottom])
            )
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 18, bottomLeading: 0, bottomTrailing: 0, topTrailing: 18),
                    style: .continuous
                )
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            // Snap animations are applied explicitly in onEnded / cycleDetent.
            // Drag-driven height changes are intentionally NOT animated so the
            // sheet tracks the finger 1:1 instead of lagging behind a spring.
            .sensoryFeedback(.impact(weight: .medium), trigger: snapFeedback)
        }
    }

    private func sheetHeight(in geo: GeometryProxy, total: CGFloat, topInset: CGFloat) -> CGFloat {
        let baseFraction = detent.fraction(
            forCollapsedHeight: collapsedHeight,
            totalHeight: total,
            topInset: topInset
        )
        let baseHeight = total * baseFraction
        // Drag down → reduce height; drag up → increase. Hard-clamp at both
        // bounds: shrinking below `collapsedHeight` would clip the header
        // (handle + search + timeline card all live there), and growing past
        // `total` just pushes the top off-screen with no visible feedback.
        let raw = baseHeight - dragTranslation
        return min(total, max(collapsedHeight, raw))
    }

    private func dragGesture(total: CGFloat, topInset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                // Amplify the velocity component of `predictedEndTranslation`
                // so a flick decisively skips detents. iOS's built-in
                // projection is conservative and tends to under-shoot the
                // gesture, which is exactly what makes the sheet feel weak.
                let velocityDelta = value.predictedEndTranslation.height
                    - value.translation.height
                let amplified = value.translation.height + velocityDelta * 1.6
                let baseHeight = total * detent.fraction(
                    forCollapsedHeight: collapsedHeight,
                    totalHeight: total,
                    topInset: topInset
                )
                let projectedHeight = baseHeight - amplified
                let next = nearestDetent(to: projectedHeight,
                                         total: total, topInset: topInset)
                let changed = next != detent
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    detent = next
                    dragTranslation = 0
                }
                if changed { snapFeedback &+= 1 }
            }
    }

    private func cycleDetent() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            switch detent {
            case .collapsed: detent = .medium
            case .medium:    detent = .expanded
            case .expanded:  detent = .collapsed
            }
        }
        snapFeedback &+= 1
    }

    private func nearestDetent(to height: CGFloat, total: CGFloat, topInset: CGFloat) -> SheetDetent {
        SheetDetent.allCases.min { a, b in
            let ha = total * a.fraction(forCollapsedHeight: collapsedHeight,
                                        totalHeight: total, topInset: topInset)
            let hb = total * b.fraction(forCollapsedHeight: collapsedHeight,
                                        totalHeight: total, topInset: topInset)
            return abs(ha - height) < abs(hb - height)
        } ?? .medium
    }
}
