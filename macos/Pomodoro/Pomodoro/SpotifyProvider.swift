//
//  SpotifyProvider.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import Foundation

final class SpotifyProvider: NowPlayingProvider {
    let sourceName = "Spotify"
    private var cachedArtworkURL: String?
    private var cachedArtwork: NSImage?

    func fetchState() async -> NowPlayingProviderState {
        guard isSpotifyInstalled() else {
            return NowPlayingProviderState(isRunning: false, isPlaying: false, title: "", artist: "", artwork: nil)
        }

        let script = """
        set isRunning to (application "Spotify" is running)
        if not isRunning then
            return {false, false, "", "", ""}
        end if
        tell application "Spotify"
            set playerState to player state
            if playerState is not playing then
                return {true, false, "", "", ""}
            end if
            set trackName to name of current track
            set artistName to artist of current track
            set artworkUrl to artwork url of current track
            return {true, true, trackName, artistName, artworkUrl}
        end tell
        """

        guard let result = await AppleScriptRunner.run(script) else {
            return NowPlayingProviderState(isRunning: false, isPlaying: false, title: "", artist: "", artwork: nil)
        }

        let isRunning = result.descriptor(at: 1)?.booleanValue ?? false
        let isPlaying = result.descriptor(at: 2)?.booleanValue ?? false
        let title = result.descriptor(at: 3)?.stringValue ?? ""
        let artist = result.descriptor(at: 4)?.stringValue ?? ""
        let artworkURLString = result.descriptor(at: 5)?.stringValue ?? ""
        let artwork = await resolveArtwork(urlString: artworkURLString)

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
        if application "Spotify" is running then
            tell application "Spotify" to playpause
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }

    func nextTrack() async {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to next track
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }

    func previousTrack() async {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to previous track
        end if
        """
        _ = await AppleScriptRunner.run(script)
    }

    private func isSpotifyInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
    }

    private func resolveArtwork(urlString: String) async -> NSImage? {
        guard !urlString.isEmpty else {
            cachedArtworkURL = nil
            cachedArtwork = nil
            return nil
        }

        if cachedArtworkURL == urlString, let cachedArtwork {
            return cachedArtwork
        }

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let image = NSImage(data: data)
            cachedArtworkURL = urlString
            cachedArtwork = image
            return image
        } catch {
            return nil
        }
    }
}
