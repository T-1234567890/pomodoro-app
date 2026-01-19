//
//  AppleMusicProvider.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import Foundation

final class AppleMusicProvider: NowPlayingProvider {
    let sourceName = "Apple Music"

    func fetchState() async -> NowPlayingProviderState {
        let script = """
        set isRunning to (application "Music" is running)
        if not isRunning then
            return {false, false, "", "", missing value}
        end if
        tell application "Music"
            set playerState to player state
            if playerState is not playing then
                return {true, false, "", "", missing value}
            end if
            set trackName to name of current track
            set artistName to artist of current track
            set artworkData to data of artwork 1 of current track
            return {true, true, trackName, artistName, artworkData}
        end tell
        """

        guard let result = await AppleScriptRunner.run(script) else {
            return NowPlayingProviderState(isRunning: false, isPlaying: false, title: "", artist: "", artwork: nil)
        }

        let isRunning = result.descriptor(at: 1)?.booleanValue ?? false
        let isPlaying = result.descriptor(at: 2)?.booleanValue ?? false
        let title = result.descriptor(at: 3)?.stringValue ?? ""
        let artist = result.descriptor(at: 4)?.stringValue ?? ""
        let artworkData = result.descriptor(at: 5)?.data
        let artwork = artworkData.flatMap { NSImage(data: $0) }

        return NowPlayingProviderState(
            isRunning: isRunning,
            isPlaying: isPlaying,
            title: title,
            artist: artist,
            artwork: artwork
        )
    }

    func playPause() async {
        let script = """
        if application "Music" is running then
            tell application "Music" to playpause
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }

    func nextTrack() async {
        let script = """
        if application "Music" is running then
            tell application "Music" to next track
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }

    func previousTrack() async {
        let script = """
        if application "Music" is running then
            tell application "Music" to previous track
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }
}

private extension NSAppleEventDescriptor {
    func descriptor(at index: Int) -> NSAppleEventDescriptor? {
        if descriptorType == typeAEList {
            return descriptor(atIndex: index)
        }
        return nil
    }
}
