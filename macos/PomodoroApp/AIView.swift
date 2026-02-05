import SwiftUI

struct AIView: View {
    @State private var prompt: String = ""
    @State private var responseText: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let aiService = AIService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Prompt")
                .font(.headline)

            TextEditor(text: $prompt)
                .frame(minHeight: 160)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )

            HStack {
                Button(action: sendPrompt) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Send to AI")
                    }
                }
                .disabled(isLoading || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            Text("Response")
                .font(.headline)

            ScrollView {
                Text(responseText.isEmpty ? "No response yet." : responseText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 120)

            Spacer()
        }
        .padding(20)
    }

    private func sendPrompt() {
        guard !isLoading else { return }
        errorMessage = nil
        responseText = ""
        isLoading = true

        let body: [String: Any] = ["prompt": prompt]

        aiService.sendAIRequest(body: body) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let text):
                    self.responseText = text
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    AIView()
}
