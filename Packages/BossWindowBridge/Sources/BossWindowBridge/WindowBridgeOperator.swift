//
//  WindowBridgeOperator.swift
//  BossWindowBridge
//
//

import Foundation
import SwiftUI

public enum OverlaySpaceLevel: Int32 {
    case kCGSSpaceAbsoluteLevelDefault = 0
    case kCGSSpaceAbsoluteLevelSetupAssistant = 100
    case kCGSSpaceAbsoluteLevelSecurityAgent = 200
    case kCGSSpaceAbsoluteLevelScreenLock = 300
    case kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock = 400
    case kCGSSpaceAbsoluteLevelBootProgress = 500
    case kCGSSpaceAbsoluteLevelVoiceOver = 600
}

public class WindowBridgeOperator {
    public static let shared = WindowBridgeOperator()

    public let connection: Int32
    public let space: Int32

    typealias F_SLSMainConnectionID = @convention(c) () -> Int32
    typealias F_SLSSpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    typealias F_SLSSpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    typealias F_SLSShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    typealias F_SLSSpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    let SLSMainConnectionID: F_SLSMainConnectionID
    let SLSSpaceCreate: F_SLSSpaceCreate
    let SLSSpaceSetAbsoluteLevel: F_SLSSpaceSetAbsoluteLevel
    let SLSShowSpaces: F_SLSShowSpaces
    let SLSSpaceAddWindowsAndRemoveFromSpaces: F_SLSSpaceAddWindowsAndRemoveFromSpaces

    private init() {
//        extern int SLSMainConnectionID(void);
//        extern int SLSSpaceCreate(int cid, int one, int zero);
//        extern CGError SLSSpaceSetAbsoluteLevel(int cid, int sid, int level);
//        extern CGError SLSShowSpaces(int cid, CFArrayRef space_list);
//        extern CGError SLSSpaceAddWindowsAndRemoveFromSpaces(int cid, int sid, CFArrayRef array, int seven);
//        extern CGError SLSShowSpaces(int cid, CFArrayRef space_list);
//        extern CGError SLSHideSpaces(int cid, CFArrayRef space_list);

        let frameworkName = ["Sky", "Light"].joined()
        let frameworkPath = "/System/Library/PrivateFrameworks/\(frameworkName).framework/Versions/A/\(frameworkName)"
        let handler = dlopen(frameworkPath, RTLD_NOW)
        SLSMainConnectionID = unsafeBitCast(dlsym(handler, "SLSMainConnectionID"), to: F_SLSMainConnectionID.self)
        SLSSpaceCreate = unsafeBitCast(dlsym(handler, "SLSSpaceCreate"), to: F_SLSSpaceCreate.self)
        SLSSpaceSetAbsoluteLevel = unsafeBitCast(dlsym(handler, "SLSSpaceSetAbsoluteLevel"), to: F_SLSSpaceSetAbsoluteLevel.self)
        SLSShowSpaces = unsafeBitCast(dlsym(handler, "SLSShowSpaces"), to: F_SLSShowSpaces.self)
        SLSSpaceAddWindowsAndRemoveFromSpaces = unsafeBitCast(dlsym(handler, "SLSSpaceAddWindowsAndRemoveFromSpaces"), to: F_SLSSpaceAddWindowsAndRemoveFromSpaces.self)

        connection = SLSMainConnectionID()
        space = SLSSpaceCreate(connection, 1, 0)
        _ = SLSSpaceSetAbsoluteLevel(
            connection,
            space,
            OverlaySpaceLevel.kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock.rawValue
        )
        _ = SLSShowSpaces(connection, [space] as CFArray)
    }

    public func delegateWindow(_ window: NSWindow) {
        _ = SLSSpaceAddWindowsAndRemoveFromSpaces(
            connection,
            space,
            [window.windowNumber] as CFArray,
            7
        )
    }

    public func delegateView(_ view: AnyView, toScreen screen: NSScreen) -> NSWindowController {
        let windowController = TopmostWindowController(screen: screen)
        windowController.window!.contentViewController = NSHostingController(rootView: view)
        windowController.window!.setFrame(screen.frame, display: true)
        delegateWindow(windowController.window!)
        windowController.window!.makeKeyAndOrderFront(nil)
        return windowController
    }
}
