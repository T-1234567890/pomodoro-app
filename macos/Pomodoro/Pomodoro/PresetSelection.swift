//
//  PresetSelection.swift
//  Pomodoro
//
//  Created by OpenAI on 3/2/25.
//

import Foundation

enum PresetSelection: Hashable {
    case preset(Preset)
    case custom

    static func selection(for durationConfig: DurationConfig) -> PresetSelection {
        if let preset = Preset.matching(durationConfig: durationConfig) {
            return .preset(preset)
        }

        return .custom
    }
}
