//
//  MusicPanelView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MusicPanelView: View {
    @EnvironmentObject private var localMusicPlayer: LocalMusicPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if localMusicPlayer.hasFiles {
                HStack(spacing: 12) {
                    Button(action: { localMusicPlayer.previous() }) {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.borderless)

                    Button(action: togglePlayback) {
                        Image(systemName: localMusicPlayer.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)

                    Button(action: { localMusicPlayer.next() }) {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.borderless)
                }
                .font(.system(size: 18, weight: .semibold))

                Text(localMusicPlayer.currentTrackName ?? "Unknown Track")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Button("Choose Music") {
                    localMusicPlayer.loadFiles()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
    }

    private func togglePlayback() {
        if localMusicPlayer.isPlaying {
            localMusicPlayer.pause()
        } else {
            localMusicPlayer.play()
        }
    }
}

#Preview {
    let appState = AppState()
    MusicPanelView()
        .environmentObject(appState.localMusicPlayer)
}
