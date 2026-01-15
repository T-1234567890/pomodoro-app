//
//  AppState.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import SwiftUI

final class AppState: ObservableObject {
    let pomodoro: PomodoroTimerEngine
    let countdown: CountdownTimerEngine

    private var cancellables: Set<AnyCancellable> = []

    init(
        pomodoro: PomodoroTimerEngine = PomodoroTimerEngine(),
        countdown: CountdownTimerEngine = CountdownTimerEngine()
    ) {
        self.pomodoro = pomodoro
        self.countdown = countdown

        pomodoro.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        countdown.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
