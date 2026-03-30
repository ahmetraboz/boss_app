//
//  BossOverlayWindow.swift
//  Boss App
//
//

import Cocoa
import BossWindowBridge

extension WindowBridgeOperator {
    func undelegateWindow(_ window: NSWindow) {
        typealias F_SLSRemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

        let frameworkName = ["Sky", "Light"].joined()
        let frameworkPath = "/System/Library/PrivateFrameworks/\(frameworkName).framework/Versions/A/\(frameworkName)"
        let handler = dlopen(frameworkPath, RTLD_NOW)
        guard let SLSRemoveWindowsFromSpaces = unsafeBitCast(
            dlsym(handler, "SLSRemoveWindowsFromSpaces"),
            to: F_SLSRemoveWindowsFromSpaces?.self
        ) else {
            return
        }
        
        // Remove the window from the overlay space
        _ = SLSRemoveWindowsFromSpaces(
            connection,
            [window.windowNumber] as CFArray,
            [space] as CFArray
        )
    }
}

class BossOverlayWindow: NSPanel {
    private var isOverlayBridgeActive: Bool = false
    
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        
        configureWindow()
    }
    
    private func configureWindow() {
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        level = .mainMenu + 3
        hasShadow = false
        isReleasedWhenClosed = false
        
        // Force dark appearance regardless of system setting
        appearance = NSAppearance(named: .darkAqua)
        
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        // Keep the overlay visible in screen recordings.
        sharingType = .readWrite
    }
    
    func activateOverlayBridge() {
        if !isOverlayBridgeActive {
            WindowBridgeOperator.shared.delegateWindow(self)
            isOverlayBridgeActive = true
        }
    }
    
    func deactivateOverlayBridge() {
        if isOverlayBridgeActive {
            WindowBridgeOperator.shared.undelegateWindow(self)
            isOverlayBridgeActive = false
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
