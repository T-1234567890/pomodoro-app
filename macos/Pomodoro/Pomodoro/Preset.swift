//
//  Preset.swift
//  Pomodoro
//
//  Created by OpenAI on 3/2/25.
//

import Foundation

struct Preset: Identifiable, Hashable {
    let id: String
    let name: String
    let durationConfig: DurationConfig

    init(name: String, durationConfig: DurationConfig) {
        self.id = name
        self.name = name
        self.durationConfig = durationConfig
    }

    static let builtIn: [Preset] = [
        Preset(
            name: "25 / 5",
            durationConfig: DurationConfig(
                workDuration: 25 * 60,
                shortBreakDuration: 5 * 60,
                longBreakDuration: 15 * 60,
                longBreakInterval: 4,
                countdownDuration: 10 * 60
            )
        ),
        Preset(
            name: "50 / 10",
            durationConfig: DurationConfig(
                workDuration: 50 * 60,
                shortBreakDuration: 10 * 60,
                longBreakDuration: 30 * 60,
                longBreakInterval: 4,
                countdownDuration: 20 * 60
            )
        ),
        Preset(
            name: "90 / 15",
            durationConfig: DurationConfig(
                workDuration: 90 * 60,
                shortBreakDuration: 15 * 60,
                longBreakDuration: 45 * 60,
                longBreakInterval: 4,
                countdownDuration: 30 * 60
            )
        )
    ]

    static func matching(durationConfig: DurationConfig) -> Preset? {
        builtIn.first { $0.durationConfig == durationConfig }
    }
}
