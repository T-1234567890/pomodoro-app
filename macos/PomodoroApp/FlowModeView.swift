import SwiftUI

/// Flow Mode: a low-density state with a single focus surface (clock) and a clear exit.
/// UI-only: no settings or persistence changes.
struct FlowModeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var countdownState: CountdownTimerState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var showsCountdown: Bool = true
    var exitAction: () -> Void = {}

    @State private var now = Date()
    @State private var countdownVisible: Bool
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(showsCountdown: Bool = true, exitAction: @escaping () -> Void = {}) {
        self.showsCountdown = showsCountdown
        self.exitAction = exitAction
        _countdownVisible = State(initialValue: showsCountdown)
    }

    var body: some View {
        ZStack {
            // Lightweight background to differentiate Flow from regular panes without fullscreen/blur.
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.96, green: 0.97, blue: 1.0, opacity: 1.0),
                    Color(.sRGB, red: 0.92, green: 0.95, blue: 0.99, opacity: 0.8),
                    Color(.sRGB, red: 0.90, green: 0.93, blue: 0.98, opacity: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .center, spacing: 0) {
                topBar

                Spacer(minLength: 32)

                clockStack
                    .padding(.horizontal, 12)

                Spacer()

                AmbientAudioStrip()
                    .environmentObject(appState)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .onReceive(clockTimer) { now = $0 }
    }

    // MARK: - UI Sections

    private var topBar: some View {
        HStack {
            Text("Flow Mode")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                countdownVisible.toggle()
            } label: {
                Image(systemName: countdownVisible ? "eye" : "eye.slash")
                    .font(.subheadline.weight(.semibold))
                Text("Timer")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Button(action: exitAction) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                    Text("Exit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit Flow Mode")
        }
    }

    private var clockStack: some View {
        VStack(spacing: 8) {
            Text(timeString)
                .font(.system(size: 92, weight: .bold, design: .rounded).monospacedDigit())
                .kerning(-0.8)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
                .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78), value: timeString)

            if shouldShowCountdown {
                countdownChip
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var countdownChip: some View {
        HStack(spacing: 8) {
            Image(systemName: countdownState.isRunning ? "timer" : "pause.circle")
                .font(.callout)
            Text(countdownTimeString)
                .font(.headline.monospacedDigit())
            Text(countdownState.isRunning ? "running" : "paused")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var timeString: String {
        now.formatted(date: .omitted, time: .shortened)
    }

    private var countdownTimeString: String {
        let totalSeconds = max(0, Int(countdownState.remainingTime))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var shouldShowCountdown: Bool {
        guard countdownVisible else { return false }
        return countdownState.isRunning || countdownState.isPaused || countdownState.remainingTime < countdownState.duration
    }
}

// MARK: - Ambient Audio

private struct AmbientAudioStrip: View {
    @EnvironmentObject private var appState: AppState
    @State private var ambientVolume: Double = 0.65

    private var isPlaying: Bool {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.isPlaying
        case .local:
            return appState.localMedia.isPlaying
        case .none:
            return false
        }
    }

    private var trackTitle: String {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.title
        case .local:
            return appState.localMedia.currentTrackTitle
        case .none:
            return "Ambient sound"
        }
    }

    private var sourceLabel: String {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.artist ?? "System player"
        case .local:
            return "Local loop"
        case .none:
            return "Tap play to start"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: appState.togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.primary)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!controlsEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(trackTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Slider(value: $ambientVolume, in: 0...1)
                .frame(width: 140)
                .tint(.primary.opacity(0.6))
                .disabled(!controlsEnabled)
                // UI-only affordance; audio engine does not expose volume yet.
                .accessibilityLabel("Ambient volume")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var controlsEnabled: Bool {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.isSessionActive
        case .local:
            return appState.localMedia.hasLoaded
        case .none:
            return true
        }
    }
}

#Preview {
    FlowModeView()
        .environmentObject(AppState())
        .environmentObject(CountdownTimerState())
}
