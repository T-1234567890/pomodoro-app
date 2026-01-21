import SwiftUI

struct CountdownTimerView: View {
    @EnvironmentObject private var countdownState: CountdownTimerState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMinutes: Int = 10
    @State private var customMinutesText: String = "10"
    @State private var statePulse = false

    private let minuteOptions = Array(stride(from: 1, through: 120, by: 1))

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Countdown Timer")
                    .font(.system(.headline, design: .default))
                Spacer()
                Text(timeString(from: countdownState.remainingTime))
                    .font(.system(size: 72, weight: .heavy, design: .default).monospacedDigit())
                    .scaleEffect(statePulse ? 1.0 : 0.98)
                    .opacity(statePulse ? 1.0 : 0.94)
                    .animation(timerAnimation, value: statePulse)
            }

            HStack(spacing: 12) {
                Picker("Duration", selection: $selectedMinutes) {
                    ForEach(minuteOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .frame(maxWidth: 160)
                .onChange(of: selectedMinutes) { newValue in
                    countdownState.setDuration(minutes: newValue)
                    customMinutesText = "\(newValue)"
                }

                HStack(spacing: 8) {
                    TextField("Custom (min)", text: $customMinutesText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            applyCustomMinutes()
                        }
                    Button("Set") {
                        applyCustomMinutes()
                    }
                    .disabled(!isCustomMinutesValid)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Start") {
                        countdownState.start()
                    }
                    .disabled(countdownState.isRunning)

                    Button("Pause") {
                        countdownState.pause()
                    }
                    .disabled(!countdownState.isRunning)

                    Button("Resume") {
                        countdownState.resume()
                    }
                    .disabled(!countdownState.isPaused)

                    Button("Reset") {
                        countdownState.reset()
                    }
                    .disabled(countdownState.remainingTime == countdownState.duration && !countdownState.isRunning)
                }
            }
        }
        .onAppear {
            let minutes = max(1, Int(countdownState.duration / 60))
            selectedMinutes = minutes
            customMinutesText = "\(minutes)"
        }
        .onChange(of: countdownState.duration) { newValue in
            let newMinutes = max(1, Int(newValue / 60))
            if newMinutes != selectedMinutes {
                selectedMinutes = newMinutes
            }
            if customMinutesText != "\(newMinutes)" {
                customMinutesText = "\(newMinutes)"
            }
        }
        .onChange(of: computedViewState) { oldValue, newValue in
            handleStateTransition(from: oldValue, to: newValue)
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var isCustomMinutesValid: Bool {
        guard let value = Int(customMinutesText.trimmingCharacters(in: .whitespaces)),
              value > 0 else {
            return false
        }
        return true
    }

    private func applyCustomMinutes() {
        guard let value = Int(customMinutesText.trimmingCharacters(in: .whitespaces)),
              value > 0 else {
            return
        }
        selectedMinutes = value
        countdownState.setDuration(minutes: value)
    }

    private var timerAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var computedViewState: CountdownViewState {
        if countdownState.isRunning {
            return .running
        }
        if countdownState.isPaused {
            return .paused
        }
        return .idle
    }

    private func handleStateTransition(from oldValue: CountdownViewState, to newValue: CountdownViewState) {
        guard shouldAnimateTransition(from: oldValue, to: newValue), !reduceMotion else { return }
        statePulse.toggle()
    }

    private func shouldAnimateTransition(from oldValue: CountdownViewState, to newValue: CountdownViewState) -> Bool {
        if oldValue == .idle && newValue == .running {
            return true
        }
        if oldValue == .running && newValue == .paused {
            return true
        }
        if oldValue != .idle && newValue == .idle {
            return true
        }
        return false
    }

    private enum CountdownViewState: Equatable {
        case idle
        case running
        case paused
    }
}

#Preview {
    CountdownTimerView()
        .environmentObject(CountdownTimerState())
        .padding()
}
