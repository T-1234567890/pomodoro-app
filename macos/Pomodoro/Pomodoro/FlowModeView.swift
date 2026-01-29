import SwiftUI
import Combine

/// Flow Mode: a low-density state with a single focus surface (clock) and a clear exit.
/// UI-only: no settings or persistence changes.
struct FlowModeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Countdown overlay is opt-in; default off to keep the clock calm (time awareness, not urgency).
    var showsCountdown: Bool = false
    var exitAction: () -> Void = {}

    @State private var countdownVisible: Bool
    @State private var isPresented = false
    @State private var sessionDissolve = false
    @State private var timerHovering = false
    @GestureState private var timerPressing = false
    @State private var exitHovering = false
    @GestureState private var exitPressing = false

    init(showsCountdown: Bool = false, exitAction: @escaping () -> Void = {}) {
        self.showsCountdown = showsCountdown
        self.exitAction = exitAction
        _countdownVisible = State(initialValue: showsCountdown)
    }

    var body: some View {
        ZStack {
            // macOS-first backdrop: real vibrancy keeps Flow Mode light without adding new textures.
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            // Subtle veil to calm high-contrast wallpapers; intentionally faint to preserve negative space.
            Color.white.opacity(0.04)
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 0) {
                topBar

                Spacer(minLength: 32)

                clockStack
                    .padding(.horizontal, 12)

                Spacer()

                AmbientAudioStrip()
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20) // a touch more negative space; Flow should feel lighter than main app
        }
        // Enter/exit feel like settling in: fade + slight scale with Apple-like easing.
        .opacity(flowOpacity)
        .scaleEffect(flowScale)
        // Flow Mode is a presentation-only context: entering/leaving must not alter timers or tasks.
        .onAppear {
            appState.isInFlowMode = true
            guard !reduceMotion else { isPresented = true; return }
            withAnimation(.easeOut(duration: 0.25)) { isPresented = true }
            triggerSessionDissolve()
        }
        .onDisappear {
            appState.isInFlowMode = false
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.20)) { isPresented = false }
        }
        .onChange(of: sessionVisualToken) { _, _ in
            triggerSessionDissolve()
        }
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
                    handleTimerTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.title3.weight(.semibold))
                        Text("Timer")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(timerHovering ? 0.12 : 0.08))
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(timerScale)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: timerPressing)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: timerHovering)
                .onHover { timerHovering = $0 }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($timerPressing) { _, state, _ in state = true }
                )
                .accessibilityLabel("Show Pomodoro timer")
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
                        .fill(Color.primary.opacity(exitHovering ? 0.12 : 0.08))
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(exitScale)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: exitPressing)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: exitHovering)
            .onHover { exitHovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($exitPressing) { _, state, _ in state = true }
            )
            .help("Return to main workspace")
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Exit Flow Mode")
        }
    }

    private var clockStack: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let currentDate = context.date
            VStack(spacing: 8) {
                Text(wallClockString(for: currentDate))
                    .font(clockFont)
                    // Fixed neutral tone: Flow clock should not signal urgency or timer state.
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .kerning(-0.8)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 10)
                    .layoutPriority(1) // keep the clock dominant; prevents compression by surrounding content
                    // Calm numeric morph to reduce tick anxiety.
                    .contentTransition(.numericText())
                    // Minutes-only animation: barely-there dissolve when minutes roll.
                    .animation(minuteMorphAnimation, value: minuteMorphToken(for: currentDate))
                    .accessibilityLabel("Current time")

                if shouldShowTimerChip {
                    timerChip
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var timerChip: some View {
        HStack(spacing: 8) {
            Image(systemName: timerIconName)
                .font(.callout)
            Text(timerTimeString)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
                // Seconds update every second: keep animation extremely subtle.
                .animation(secondTickAnimation, value: timerTimeString)
            Text(timerStatusLabel)
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
        // Soft dissolve on session changes; keeps interaction live.
        .opacity(sessionOpacity)
        .blur(radius: sessionBlur)
        // Overlay is intentionally lightweight; tap pauses/resumes, long-press or secondary click hides.
        .onTapGesture { toggleActiveTimer() }
        .onLongPressGesture { countdownVisible.toggle() }
        .gesture(
            TapGesture()
                .modifiers(.command) // secondary-like quick hide
                .onEnded { countdownVisible.toggle() }
        )
    }

    // MARK: - Helpers

    private func wallClockString(for date: Date) -> String {
        // System wall-clock time; locale-aware 12/24h, no seconds for calmer display.
        date.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute(.twoDigits)
        )
    }
    
    /// Token used to trigger a soft morph only when minutes change.
    private func minuteMorphToken(for date: Date) -> String {
        date.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute(.twoDigits)
        )
    }
    
    /// Token representing session state changes for dissolve animation.
    private var sessionVisualToken: String {
        "\(appState.isInFlowMode)-\(appState.pomodoro.state.rawValue)"
    }

    private var countdownTimeString: String {
        let totalSeconds = max(0, Int(appState.countdown.remainingSeconds))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerTimeString: String {
        let totalSeconds = max(0, appState.pomodoro.remainingSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var shouldShowTimerChip: Bool {
        appState.pomodoro.state != .idle
    }

    // MARK: - Clock styling

    private var clockFont: Font {
        // Large type keeps the clock the visual center without adding motion.
        .system(size: 104, weight: .heavy, design: .rounded).monospacedDigit()
    }

    // MARK: - Timer wiring (observes existing engines, never duplicates logic)

    private enum ActiveTimer {
        case pomodoro(state: TimerState, remaining: Int)
        case countdown(state: TimerState, remaining: Int)
    }

    private var currentActiveTimer: ActiveTimer? {
        if appState.pomodoro.state != .idle {
            return .pomodoro(state: appState.pomodoro.state, remaining: appState.pomodoro.remainingSeconds)
        }
        if appState.countdown.state != .idle {
            return .countdown(state: appState.countdown.state, remaining: appState.countdown.remainingSeconds)
        }
        return nil
    }

    private var activeTimerRemainingSeconds: Int {
        switch currentActiveTimer {
        case .pomodoro(_, let remaining): return remaining
        case .countdown(_, let remaining): return remaining
        case .none: return appState.pomodoro.remainingSeconds
        }
    }

    private var timerIconName: String {
        switch appState.pomodoro.state {
        case .running, .breakRunning:
            return "timer"
        case .paused, .breakPaused:
            return "pause.circle"
        case .idle:
            return "timer"
        }
    }

    private var timerStatusLabel: String {
        switch appState.pomodoro.state {
        case .running:
            return "running"
        case .breakRunning:
            return "break"
        case .paused, .breakPaused:
            return "paused"
        case .idle:
            return "ready"
        }
    }

    private func handleTimerTap() {
        // Reveal timer state and control the shared Pomodoro engine.
        countdownVisible = true
        startOrTogglePomodoro()
    }

    private func toggleActiveTimer() {
        switch appState.pomodoro.state {
        case .idle:
            appState.startPomodoro()
        case .running, .breakRunning:
            appState.pomodoro.pause()
        case .paused, .breakPaused:
            appState.pomodoro.resume()
        }
    }

    private func startOrTogglePomodoro() {
        switch appState.pomodoro.state {
        case .idle:
            appState.startPomodoro()
        case .running, .breakRunning:
            appState.pomodoro.pause()
        case .paused, .breakPaused:
            appState.pomodoro.resume()
        }
    }
}

private extension FlowModeView {
    var timerScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return timerPressing ? 0.98 : 1.0
    }
    
    var exitScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return exitPressing ? 0.98 : 1.0
    }
    
    var flowScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isPresented ? 1.0 : 0.98
    }
    
    var flowOpacity: Double {
        guard !reduceMotion else { return 1.0 }
        return isPresented ? 1.0 : 0.0
    }
    
    var timeUpdateAnimation: Animation? {
        // Very light easing to make digits "flow" instead of tick.
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }
    
    var minuteMorphAnimation: Animation? {
        // Slightly fuller dissolve for minute transitions; still calm and short.
        reduceMotion ? nil : .easeOut(duration: 0.2)
    }
    
    var secondTickAnimation: Animation? {
        // Near-invisible change each second to avoid flicker stress.
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
    
    var sessionTransitionAnimation: Animation {
        .easeOut(duration: 0.2)
    }
    
    var sessionOpacity: Double {
        guard !reduceMotion else { return 1.0 }
        return sessionDissolve ? 0.6 : 1.0
    }
    
    var sessionBlur: CGFloat {
        guard !reduceMotion else { return 0 }
        return sessionDissolve ? 1.2 : 0
    }
    
    func triggerSessionDissolve() {
        guard !reduceMotion else { return }
        sessionDissolve = true
        withAnimation(sessionTransitionAnimation) {
            sessionDissolve = false
        }
    }
}

// MARK: - Ambient Audio

private struct AmbientAudioStrip: View {
    @EnvironmentObject private var musicController: MusicController
    @EnvironmentObject private var audioSourceStore: AudioSourceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambientVolume: Double = 0.4
    @State private var sliderEditing = false
    @State private var sliderHover = false

    var body: some View {
        Group {
            if audioSourceStore.externalMediaDetected, let media = audioSourceStore.externalMediaMetadata {
                externalStrip(media)
            } else {
                ambientStrip
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            ambientVolume = Double(musicController.focusVolume)
        }
    }

    private var ambientStrip: some View {
        HStack(spacing: 14) {
            Button(action: toggleAmbient) {
                Image(systemName: musicController.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                soundIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .foregroundStyle(.primary.opacity(0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(ambientTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("Ambient · Local")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Slider(
                value: $ambientVolume,
                in: 0...1,
                onEditingChanged: { editing in
                    if reduceMotion {
                        sliderEditing = editing
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { sliderEditing = editing }
                    }
                },
                minimumValueLabel: Image(systemName: "speaker.wave.1.fill").foregroundStyle(.secondary),
                maximumValueLabel: Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary),
                label: { EmptyView() }
            )
            .frame(width: 180)
            .tint(.primary.opacity(0.65))
            // Smooth track fill animation; matches macOS slider feel.
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ambientVolume)
            // Knob scales very slightly while dragging; no layout change.
            .scaleEffect(sliderEditing ? 1.03 : 1.0, anchor: .center)
            // Hover brightens softly to indicate focus without glow.
            .opacity((sliderHover || sliderEditing) ? 1.0 : 0.95)
            .onHover { hovering in
                if reduceMotion {
                    sliderHover = hovering
                } else {
                    withAnimation(.easeOut(duration: 0.18)) { sliderHover = hovering }
                }
            }
            .accessibilityLabel("Ambient volume")
            .onChange(of: ambientVolume) { _, newValue in
                audioSourceStore.setVolume(Float(newValue))
            }
        }
    }

    private func externalStrip(_ media: ExternalMedia) -> some View {
        HStack(spacing: 14) {
            artwork(for: media)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Now Playing · \(media.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(media.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(media.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private func toggleAmbient() {
        audioSourceStore.togglePlayPause()
    }

    private var ambientTitle: String {
        if case .ambient(let type) = audioSourceStore.audioSource {
            return type.displayName
        }
        return musicController.currentFocusSound == .off ? "White Noise" : musicController.currentFocusSound.displayName
    }

    private var soundIcon: Image {
        switch musicController.currentFocusSound {
        case .white, .off:
            return Image(systemName: "waveform")
        case .brown:
            return Image(systemName: "wind")
        case .rain:
            return Image(systemName: "cloud.rain")
        case .wind:
            return Image(systemName: "wind.circle")
        }
    }

    @ViewBuilder
    private func artwork(for media: ExternalMedia) -> some View {
        if let artwork = media.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let appState = AppState()
    let musicController = MusicController(ambientNoiseEngine: appState.ambientNoiseEngine)
    let audioSourceStore: AudioSourceStore = MainActor.assumeIsolated {
        let externalMonitor = ExternalAudioMonitor()
        let externalController = ExternalPlaybackController()
        return AudioSourceStore(
            musicController: musicController,
            externalMonitor: externalMonitor,
            externalController: externalController
        )
    }
    FlowModeView()
        .environmentObject(appState)
        .environmentObject(musicController)
        .environmentObject(audioSourceStore)
}
