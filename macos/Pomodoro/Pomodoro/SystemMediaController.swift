//
//  SystemMediaController.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit

struct SystemMediaController {
    private enum MediaKey: Int32 {
        case playPause = 16
        case next = 17
        case previous = 18
    }

    func playPause() {
        postMediaKey(.playPause)
    }

    func nextTrack() {
        postMediaKey(.next)
    }

    func previousTrack() {
        postMediaKey(.previous)
    }

    private func postMediaKey(_ key: MediaKey) {
        postMediaKey(key, keyDown: true)
        postMediaKey(key, keyDown: false)
    }

    private func postMediaKey(_ key: MediaKey, keyDown: Bool) {
        let keyCode = key.rawValue
        let keyState: Int32 = keyDown ? 0xA00 : 0xB00
        let data1 = (keyCode << 16) | keyState
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int(data1),
            data2: -1
        ) else {
            return
        }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
