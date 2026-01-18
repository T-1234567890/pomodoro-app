import SwiftUI

struct MediaControlBar: View {
    @ObservedObject var player: LocalMediaPlayer

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = player.currentArtwork {
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

            Text(player.currentTrackTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: player.togglePlayPause) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)

                Button(action: player.next) {
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
    MediaControlBar(player: LocalMediaPlayer())
        .padding()
}
