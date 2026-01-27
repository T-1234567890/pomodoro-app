import SwiftUI
import Combine

/// Flow Mode: a low-density state with a single focus surface (clock) and a clear exit.
/// UI-only: no settings or persistence changes.
struct FlowModeView: View {
    @EnvironmentObject private var appState: AppState
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
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .onReceive(clockTimer) { now = $0 }
    }

    // MARK: - UI Sections

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus State")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Calm time awareness")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    // Placeholder: timer toggle will be added later.
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.subheadline.weight(.semibold))
                        Text("Timer (coming soon)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .foregroundStyle(.secondary)
                .disabled(true)

                Text("Optional · not required for Flow")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: exitAction) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                    Text("Exit Flow")
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
            .help("Return to main workspace")
            .accessibilityLabel("Exit Flow Mode")
        }
    }

    private var clockStack: some View {
        VStack(spacing: 8) {
            Text(timeString)
                .font(.system(size: 92, weight: .bold, design: .rounded).monospacedDigit())
                .kerning(-0.8)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 5)

            if shouldShowCountdown {
                countdownChip
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var countdownChip: some View {
        HStack(spacing: 8) {
            Image(systemName: isCountdownRunning ? "timer" : "pause.circle")
                .font(.callout)
            Text(countdownTimeString)
                .font(.headline.monospacedDigit())
            Text(isCountdownRunning ? "running" : "paused")
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
        let totalSeconds = max(0, Int(appState.countdown.remainingSeconds))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var shouldShowCountdown: Bool {
        guard countdownVisible else { return false }
        return isCountdownRunning || isCountdownActive
    }

    private var isCountdownRunning: Bool {
        appState.countdown.state == .running
    }

    private var isCountdownActive: Bool {
        appState.countdown.state == .paused || appState.countdown.state == .running
    }
}

// MARK: - Ambient Audio

private struct AmbientAudioStrip: View {
    @State private var ambientVolume: Double = 0.65
    var isPlaying: Bool = false
    var title: String = "Ambient sound"
    var subtitle: String = "Optional background audio to support focus"
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
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
            .disabled(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Slider(value: $ambientVolume, in: 0...1)
                .frame(width: 140)
                .tint(.primary.opacity(0.6))
                .disabled(true)
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
}

#Preview {
    FlowModeView()
        .environmentObject(AppState())
}
