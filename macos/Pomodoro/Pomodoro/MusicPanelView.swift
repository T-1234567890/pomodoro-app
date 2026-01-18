//
//  MusicPanelView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MusicPanelView: View {
    @EnvironmentObject private var musicController: MusicController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button(action: { musicController.previous() }) {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.borderless)
                .disabled(musicController.activeSource == .focusSound)

                Button(action: togglePlayback) {
                    Image(systemName: musicController.playbackState == .playing ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)

                Button(action: { musicController.next() }) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.borderless)
                .disabled(musicController.activeSource == .focusSound)
            }
            .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Ambient Sound")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("Ambient Sound", selection: focusSoundBinding) {
                    ForEach(FocusSoundType.allCases) { sound in
                        Text(sound.displayName)
                            .tag(sound)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
    }

    private var focusSoundBinding: Binding<FocusSoundType> {
        Binding(
            get: { musicController.currentFocusSound },
            set: { newValue in
                if newValue == .off {
                    musicController.stopFocusSound()
                } else {
                    musicController.startFocusSound(newValue)
                }
            }
        )
    }

    private func togglePlayback() {
        if musicController.playbackState == .playing {
            musicController.pause()
        } else {
            musicController.play()
        }
    }
}

#Preview {
    MusicPanelView()
        .environmentObject(MusicController())
}
