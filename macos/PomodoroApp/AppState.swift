import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject, DynamicProperty {
    @Published var currentMode: PomodoroMode = .idle
    @Published var completedWorkSessions: Int = 0
    @Published var workDuration: Int = 25 * 60
    @Published var breakDuration: Int = 5 * 60
    @Published var longBreakDuration: Int = 15 * 60
    @Published var activeMediaSource: ActiveMediaSource = .none
    @Published var lastActiveMediaSource: ActiveMediaSource = .none
    @StateObject var systemMedia = SystemMediaController()
    @StateObject var localMedia = LocalMediaPlayer()

    private let lastActiveSourceKey = "lastActiveMediaSource"
    private var cancellables = Set<AnyCancellable>()
    private var shouldResumeLocalAfterSystem = false

    init() {
        restoreLastActiveMediaSource()
        bindMediaUpdates()
        updateActiveMediaSource()
    }

    func setWorkDuration(minutes: Int) {
        workDuration = minutes * 60
    }

    func update() {}

    func togglePlayPause() {
        switch activeMediaSource {
        case .system:
            systemMedia.togglePlayPause()
        case .local:
            localMedia.togglePlayPause()
        case .none:
            break
        }
    }

    func nextTrack() {
        switch activeMediaSource {
        case .system:
            systemMedia.nextTrack()
        case .local:
            localMedia.next()
        case .none:
            break
        }
    }

    func previousTrack() {
        switch activeMediaSource {
        case .system:
            systemMedia.previousTrack()
        case .local:
            localMedia.previous()
        case .none:
            break
        }
    }

    private func bindMediaUpdates() {
        systemMedia.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.handleSystemActivityChange(isActive: isActive)
            }
            .store(in: &cancellables)

        systemMedia.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.handleSystemPlaybackChange(isPlaying: isPlaying)
            }
            .store(in: &cancellables)

        localMedia.$hasLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveMediaSource()
            }
            .store(in: &cancellables)

        localMedia.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.handleLocalPlaybackChange(isPlaying: isPlaying)
            }
            .store(in: &cancellables)
    }

    private func handleSystemActivityChange(isActive: Bool) {
        if isActive {
            if localMedia.isPlaying {
                shouldResumeLocalAfterSystem = true
                localMedia.pause()
            }
            setActiveMediaSource(.system)
        } else {
            if activeMediaSource == .system, shouldResumeLocalAfterSystem, localMedia.hasLoaded {
                localMedia.play()
            }
            shouldResumeLocalAfterSystem = false
            updateActiveMediaSource()
        }
    }

    private func handleSystemPlaybackChange(isPlaying: Bool) {
        guard systemMedia.isActive else {
            updateActiveMediaSource()
            return
        }

        if isPlaying, localMedia.isPlaying {
            shouldResumeLocalAfterSystem = true
            localMedia.pause()
        }
        setActiveMediaSource(.system)
    }

    private func handleLocalPlaybackChange(isPlaying: Bool) {
        guard activeMediaSource != .system else { return }
        if isPlaying {
            setActiveMediaSource(.local)
        } else {
            updateActiveMediaSource()
        }
    }

    private func updateActiveMediaSource() {
        if systemMedia.isActive {
            setActiveMediaSource(.system)
        } else if localMedia.hasLoaded {
            setActiveMediaSource(.local)
        } else {
            activeMediaSource = lastActiveMediaSource
        }
    }

    private func setActiveMediaSource(_ source: ActiveMediaSource) {
        activeMediaSource = source
        guard source != .none else { return }
        lastActiveMediaSource = source
        UserDefaults.standard.set(source.rawValue, forKey: lastActiveSourceKey)
    }

    private func restoreLastActiveMediaSource() {
        if let storedValue = UserDefaults.standard.string(forKey: lastActiveSourceKey),
           let restoredSource = ActiveMediaSource(rawValue: storedValue) {
            lastActiveMediaSource = restoredSource
            activeMediaSource = restoredSource
        }
    }
}
