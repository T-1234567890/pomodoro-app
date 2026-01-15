import SwiftUI

struct MainWindowView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Pomodoro")
                .font(.largeTitle)
            Text("Ready to focus.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding(32)
    }
}

#Preview {
    MainWindowView()
}
