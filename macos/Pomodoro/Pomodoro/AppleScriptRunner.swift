//
//  AppleScriptRunner.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Foundation

enum AppleScriptRunner {
    static func run(_ script: String) async -> NSAppleEventDescriptor? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                let result = appleScript?.executeAndReturnError(&error)
                continuation.resume(returning: result)
            }
        }
    }
}
