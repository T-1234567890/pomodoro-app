//
//  DurationConfig.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Foundation

struct DurationConfig: Equatable, Hashable {
    private enum DefaultsKey {
        static let workDuration = "durationConfig.workDuration"
        static let shortBreakDuration = "durationConfig.shortBreakDuration"
        static let longBreakDuration = "durationConfig.longBreakDuration"
        static let longBreakInterval = "durationConfig.longBreakInterval"
        static let countdownDuration = "durationConfig.countdownDuration"
    }

    let workDuration: Int
    let shortBreakDuration: Int
    let longBreakDuration: Int
    let longBreakInterval: Int
    let countdownDuration: Int

    init(
        workDuration: Int,
        shortBreakDuration: Int,
        longBreakDuration: Int,
        longBreakInterval: Int,
        countdownDuration: Int = 10 * 60
    ) {
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.longBreakInterval = max(1, longBreakInterval)
        self.countdownDuration = countdownDuration
    }

    static let standard = DurationConfig(
        workDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        longBreakInterval: 4,
        countdownDuration: 10 * 60
    )

    static func load(from defaults: UserDefaults) -> DurationConfig {
        let workDurationValue = defaults.object(forKey: DefaultsKey.workDuration) as? NSNumber
        let shortBreakDurationValue = defaults.object(forKey: DefaultsKey.shortBreakDuration) as? NSNumber
        let longBreakDurationValue = defaults.object(forKey: DefaultsKey.longBreakDuration) as? NSNumber
        let longBreakIntervalValue = defaults.object(forKey: DefaultsKey.longBreakInterval) as? NSNumber
        let countdownDurationValue = defaults.object(forKey: DefaultsKey.countdownDuration) as? NSNumber

        guard
            let workDuration = workDurationValue?.intValue,
            let shortBreakDuration = shortBreakDurationValue?.intValue,
            let longBreakDuration = longBreakDurationValue?.intValue,
            let longBreakInterval = longBreakIntervalValue?.intValue
        else {
            return .standard
        }

        let countdownDuration = countdownDurationValue?.intValue ?? 10 * 60

        return DurationConfig(
            workDuration: workDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            longBreakInterval: longBreakInterval,
            countdownDuration: countdownDuration
        )
    }

    func save(to defaults: UserDefaults) {
        defaults.set(workDuration, forKey: DefaultsKey.workDuration)
        defaults.set(shortBreakDuration, forKey: DefaultsKey.shortBreakDuration)
        defaults.set(longBreakDuration, forKey: DefaultsKey.longBreakDuration)
        defaults.set(longBreakInterval, forKey: DefaultsKey.longBreakInterval)
        defaults.set(countdownDuration, forKey: DefaultsKey.countdownDuration)
    }
}
