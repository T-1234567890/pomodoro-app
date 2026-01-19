//
//  MediaControlBar.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MediaControlBar: View {
    @EnvironmentObject private var nowPlaying: NowPlayingRouter

    var body: some View {
        HStack(spacing: 12) {
            if nowPlaying.isAvailable {
                artworkView

                VStack(alignment: .leading, spacing: 4) {
                    Text(nowPlaying.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(nowPlaying.artist) • \(nowPlaying.sourceName)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    nowPlaying.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(.ultraThinMaterial))

                Button {
                    nowPlaying.playPause()
                } label: {
                    Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(.ultraThinMaterial))

                Button {
                    nowPlaying.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(.ultraThinMaterial))
            } else {
                ZStack {
                    Circle()
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("No supported music playing")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Start Apple Music or Spotify")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.2))
        )
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 32, height: 32)
        }
    }
}

#Preview {
    MediaControlBar()
        .environmentObject(NowPlayingRouter())
        .padding()
}
