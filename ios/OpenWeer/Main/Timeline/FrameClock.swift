import SwiftUI

@Observable
@MainActor
final class FrameClock {
    var isPlaying = false
    private var task: Task<Void, Never>?

    func start(framesCount: Int, advance: @escaping @MainActor () -> Void, intervalMs: Int = 220) {
        stop()
        guard framesCount > 0 else { return }
        isPlaying = true
        task = Task { @MainActor [weak self] in
            while let self, self.isPlaying, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(intervalMs))
                advance()
            }
        }
    }

    func stop() {
        isPlaying = false
        task?.cancel()
        task = nil
    }
}
