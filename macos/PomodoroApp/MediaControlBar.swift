import SwiftUI

struct MediaControlBar: View {
    @EnvironmentObject private var appState: AppState

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
            return appState.localMedia.currentTrackTitle
        }
    }

    private var sourceLabel: String {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.isSessionActive ? "System Audio" : "System Audio (Inactive)"
        case .local:
            return "Local Audio"
        case .none:
            return "Local Audio"
        }
    }

    private var artwork: NSImage? {
        switch appState.activeMediaSource {
        case .system:
            return appState.systemMedia.artwork
        case .local:
            return appState.localMedia.currentArtwork
        case .none:
            return appState.localMedia.currentArtwork
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(trackTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(appState.activeMediaSource == .system && !appState.systemMedia.isSessionActive ? .orange : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: appState.previousTrack) {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.plain)

                Button(action: appState.togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)

                Button(action: appState.nextTrack) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    MediaControlBar()
        .environmentObject(AppState())
        .padding()
}
