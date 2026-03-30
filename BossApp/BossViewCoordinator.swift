//
//  BossViewCoordinator.swift
//  Boss App
//
//

import AppKit
import BossConfig
import SwiftUI

@MainActor
class BossViewCoordinator: ObservableObject {
    static let shared = BossViewCoordinator()

    @Published var currentView: NotchViews = .home {
        didSet {
            if currentView != .clipboard && isClipboardExpanded {
                setClipboardExpanded(false)
            }
            if currentView != .screenshots && isScreenshotsExpanded {
                setScreenshotsExpanded(false)
            }
            if currentView != .notes && isNotesExpanded {
                setNotesExpanded(false)
            }
        }
    }
    @Published private(set) var isClipboardExpanded: Bool = false
    @Published private(set) var isScreenshotsExpanded: Bool = false
    @Published private(set) var isNotesExpanded: Bool = false

    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    @AppStorage("showWhatsNew") var showWhatsNew: Bool = true
    @AppStorage("musicLiveActivityEnabled") var musicLiveActivityEnabled: Bool = true

    @AppStorage("alwaysShowTabs") var alwaysShowTabs: Bool = true {
        didSet {
            if !alwaysShowTabs {
                openLastTabByDefault = false
                if ShelfStateViewModel.shared.isEmpty || !BossConfig[.openShelfByDefault] {
                    currentView = .home
                }
            }
        }
    }

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = false {
        didSet {
            if openLastTabByDefault {
                alwaysShowTabs = true
            }
        }
    }
    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    private init() {
        // Perform migration from name-based to UUID-based storage
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            // Clear legacy value after migration
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
    }
    func showEmpty() {
        currentView = .home
    }

    func toggleClipboardExpanded() {
        setClipboardExpanded(!isClipboardExpanded)
    }

    func setClipboardExpanded(_ expanded: Bool) {
        guard isClipboardExpanded != expanded else { return }

        isClipboardExpanded = expanded
        NotificationCenter.default.post(name: .clipboardExpansionChanged, object: nil)
    }

    func toggleScreenshotsExpanded() {
        setScreenshotsExpanded(!isScreenshotsExpanded)
    }

    func setScreenshotsExpanded(_ expanded: Bool) {
        guard isScreenshotsExpanded != expanded else { return }

        isScreenshotsExpanded = expanded
        NotificationCenter.default.post(name: .screenshotsExpansionChanged, object: nil)
    }

    func toggleNotesExpanded() {
        setNotesExpanded(!isNotesExpanded)
    }

    func setNotesExpanded(_ expanded: Bool) {
        guard isNotesExpanded != expanded else { return }

        isNotesExpanded = expanded
        NotificationCenter.default.post(name: .notesExpansionChanged, object: nil)
    }
}
