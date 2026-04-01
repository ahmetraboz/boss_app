//
//  BossAppHelperProtocol.swift
//  BossAppHelper
//
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol BossAppHelperProtocol {
    // Keyboard backlight / CoreBrightness access (performed by the helper)
    func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screen brightness access (performed by the helper)
    func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screenshot listing (performed by the helper - no sandbox restrictions)
    func getScreenshotPaths(limit: Int, with reply: @escaping ([String]) -> Void)
    func getScreenshotPaths(
        inFolder path: String, limit: Int, with reply: @escaping ([String]) -> Void)
    // File operations (performed by the helper for sandbox-restricted paths)
    func readFileData(atPath path: String, with reply: @escaping (NSData?) -> Void)
    func trashFile(atPath path: String, with reply: @escaping (Bool) -> Void)
    func openFile(atPath path: String, with reply: @escaping (Bool) -> Void)
    func revealFile(atPath path: String, with reply: @escaping (Bool) -> Void)
}
