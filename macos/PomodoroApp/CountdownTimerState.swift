import Foundation

@MainActor
final class CountdownTimerState: ObservableObject {
    @Published private(set) var duration: TimeInterval
    @Published private(set) var remainingTime: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false

    private let durationKey = "countdownDurationSeconds"
    private var timer: Timer?

    init() {
        let storedDuration = UserDefaults.standard.double(forKey: durationKey)
        let initialDuration = storedDuration > 0 ? storedDuration : 10 * 60
        duration = initialDuration
        remainingTime = initialDuration
    }

    func setDuration(minutes: Int) {
        let newDuration = TimeInterval(minutes * 60)
        duration = newDuration
        remainingTime = newDuration
        persistDuration()
        stopTimer()
        isPaused = false
    }

    func start() {
        guard !isRunning else { return }
        if remainingTime <= 0 {
            remainingTime = duration
        }
        isRunning = true
        isPaused = false
        startTimer()
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        isPaused = true
        stopTimer()
    }

    func resume() {
        guard !isRunning, isPaused, remainingTime > 0 else { return }
        isRunning = true
        isPaused = false
        startTimer()
    }

    func reset() {
        isRunning = false
        isPaused = false
        remainingTime = duration
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingTime > 0 else {
            remainingTime = 0
            isRunning = false
            isPaused = false
            stopTimer()
            return
        }
        remainingTime -= 1
    }

    private func persistDuration() {
        UserDefaults.standard.set(duration, forKey: durationKey)
    }
}
