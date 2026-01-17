//
//  DurationConfig.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Foundation

struct DurationConfig: Equatable {
    let workDuration: Int
    let shortBreakDuration: Int
    let longBreakDuration: Int
    let longBreakInterval: Int

    init(
        workDuration: Int,
        shortBreakDuration: Int,
        longBreakDuration: Int,
        longBreakInterval: Int
    ) {
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.longBreakInterval = max(1, longBreakInterval)
    }

    static let standard = DurationConfig(
        workDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        longBreakInterval: 4
    )
}
