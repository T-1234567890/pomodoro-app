import SwiftUI

struct CountdownTimerView: View {
    @EnvironmentObject private var countdownState: CountdownTimerState
    @State private var selectedMinutes: Int = 10

    private let minuteOptions = Array(stride(from: 1, through: 120, by: 1))

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Countdown Timer")
                    .font(.headline)
                Spacer()
                Text(timeString(from: countdownState.remainingTime))
                    .font(.title3)
                    .monospacedDigit()
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
            selectedMinutes = max(1, Int(countdownState.duration / 60))
        }
        .onChange(of: countdownState.duration) { newValue in
            let newMinutes = max(1, Int(newValue / 60))
            if newMinutes != selectedMinutes {
                selectedMinutes = newMinutes
            }
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
}

#Preview {
    CountdownTimerView()
        .environmentObject(CountdownTimerState())
        .padding()
}
