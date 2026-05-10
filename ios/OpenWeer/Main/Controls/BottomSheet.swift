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
        case .expanded:  return max(0.55, 1 - (topInset + 24) / totalHeight)
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
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.84), value: detent)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.84), value: dragTranslation)
        }
    }

    private func sheetHeight(in geo: GeometryProxy, total: CGFloat, topInset: CGFloat) -> CGFloat {
        let baseFraction = detent.fraction(
            forCollapsedHeight: collapsedHeight,
            totalHeight: total,
            topInset: topInset
        )
        let baseHeight = total * baseFraction
        // Drag down → reduce height; drag up → increase.
        let h = baseHeight - dragTranslation
        let minH = collapsedHeight
        let maxH = total - max(topInset + 24, 24)
        return min(maxH, max(minH, h))
    }

    private func dragGesture(total: CGFloat, topInset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let projectedDelta = value.predictedEndTranslation.height
                let baseHeight = total * detent.fraction(
                    forCollapsedHeight: collapsedHeight,
                    totalHeight: total,
                    topInset: topInset
                )
                let projectedHeight = baseHeight - projectedDelta
                detent = nearestDetent(to: projectedHeight, total: total, topInset: topInset)
                dragTranslation = 0
            }
    }

    private func cycleDetent() {
        switch detent {
        case .collapsed: detent = .medium
        case .medium:    detent = .expanded
        case .expanded:  detent = .collapsed
        }
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
