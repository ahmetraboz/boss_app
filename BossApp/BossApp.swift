//
//  BossApp.swift
//  Boss App
//
//

import AppKit
import BossConfig
import Combine
import SwiftUI

@main
struct BossAppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        ClipboardStateViewModel.shared.startMonitoring()
        ScreenshotStateViewModel.shared.startMonitoring()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.shared.showWindow()
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
        }
    }
}

@MainActor
final class BossMenuBarController: NSObject {
    private enum Layout {
        static let separatorLength: CGFloat = 12
        static let minimumCollapsedLength: CGFloat = 500
        static let maximumCollapsedLength: CGFloat = 4000
        static let collapsedExtraPadding: CGFloat = 200
    }

    private var toggleItem: NSStatusItem?
    private var separatorItem: NSStatusItem?
    private var menuBarIconCancellable: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var isToggleLocked = false

    private var collapsedLength: CGFloat {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1728
        return max(
            Layout.minimumCollapsedLength,
            min(screenWidth + Layout.collapsedExtraPadding, Layout.maximumCollapsedLength)
        )
    }

    private var isCollapsed: Bool {
        guard let separatorItem else { return false }
        return separatorItem.length >= collapsedLength - 1
    }

    func start() {
        menuBarIconCancellable = BossConfig.publisher(.menubarIcon)
            .map(\.newValue)
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self else { return }
                Task { @MainActor in
                    self.setVisible(isVisible)
                }
            }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCollapsedLayoutIfNeeded()
            }
        }
    }

    func stop() {
        menuBarIconCancellable?.cancel()
        menuBarIconCancellable = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        removeItems()
    }

    private func setVisible(_ visible: Bool) {
        if visible {
            createItemsIfNeeded()
        } else {
            removeItems()
        }
    }

    private func createItemsIfNeeded() {
        guard toggleItem == nil, separatorItem == nil else { return }

        let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = toggleItem.button {
            button.title = "🐻"
            button.target = self
            button.action = #selector(handleToggleItemPress(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        toggleItem.autosaveName = "bossapp_bear_toggle"
        self.toggleItem = toggleItem

        let separatorItem = NSStatusBar.system.statusItem(withLength: Layout.separatorLength)
        if let button = separatorItem.button {
            button.title = "│"
            button.font = NSFont.systemFont(ofSize: 14, weight: .regular)
            button.appearsDisabled = true
            button.isEnabled = false
        }
        separatorItem.autosaveName = "bossapp_bear_separator"
        self.separatorItem = separatorItem
    }

    private func removeItems() {
        if let toggleItem {
            NSStatusBar.system.removeStatusItem(toggleItem)
            self.toggleItem = nil
        }

        if let separatorItem {
            NSStatusBar.system.removeStatusItem(separatorItem)
            self.separatorItem = nil
        }
    }

    private func refreshCollapsedLayoutIfNeeded() {
        guard isCollapsed, let separatorItem else { return }
        separatorItem.length = collapsedLength
    }

    private var isSeparatorPositionValid: Bool {
        guard
            let toggleX = toggleItem?.button?.window?.frame.origin.x,
            let separatorX = separatorItem?.button?.window?.frame.origin.x
        else {
            return true
        }

        if NSApplication.shared.userInterfaceLayoutDirection == .leftToRight {
            return toggleX >= separatorX
        }

        return toggleX <= separatorX
    }

    @objc
    private func handleToggleItemPress(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            toggleCollapse()
            return
        }

        let isRightClick = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            showContextMenu()
            return
        }

        toggleCollapse()
    }

    private func toggleCollapse() {
        guard !isToggleLocked else { return }
        guard isSeparatorPositionValid else {
            NSSound.beep()
            return
        }

        isToggleLocked = true

        if isCollapsed {
            separatorItem?.length = Layout.separatorLength
        } else {
            separatorItem?.length = collapsedLength
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.isToggleLocked = false
        }
    }

    private func showContextMenu() {
        guard let toggleItem else { return }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let restartItem = NSMenuItem(
            title: "Restart Boss App",
            action: #selector(restartApplication),
            keyEquivalent: ""
        )
        restartItem.target = self
        menu.addItem(restartItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc
    private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc
    private func restartApplication() {
        ApplicationRelauncher.restart()
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = BossMenuBarController()
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: BossViewModel] = [:] // UUID -> BossViewModel
    var window: NSWindow?
    let vm: BossViewModel = .init()
    @ObservedObject var coordinator = BossViewCoordinator.shared
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        MusicManager.shared.destroy()
        ClipboardStateViewModel.shared.stopMonitoring()
        ScreenshotStateViewModel.shared.stopMonitoring()
        menuBarController.stop()
        cleanupDragDetectors()
        cleanupWindows()
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        activateOverlayBridgeOnAllWindows()
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        deactivateOverlayBridgeOnAllWindows()
    }
    
    @MainActor
    private func activateOverlayBridgeOnAllWindows() {
        if BossConfig[.showOnAllDisplays] {
            windows.values.forEach { window in
                if let overlayWindow = window as? BossOverlayWindow {
                    overlayWindow.activateOverlayBridge()
                }
            }
        } else {
            if let overlayWindow = window as? BossOverlayWindow {
                overlayWindow.activateOverlayBridge()
            }
        }
    }
    
    @MainActor
    private func deactivateOverlayBridgeOnAllWindows() {
        // Delay disabling the overlay bridge to avoid flicker during unlock transition
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if BossConfig[.showOnAllDisplays] {
                    self.windows.values.forEach { window in
                        if let overlayWindow = window as? BossOverlayWindow {
                            overlayWindow.deactivateOverlayBridge()
                        }
                    }
                } else {
                    if let overlayWindow = self.window as? BossOverlayWindow {
                        overlayWindow.deactivateOverlayBridge()
                    }
                }
            }
        }
    }

    private func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !BossConfig[.showOnAllDisplays] : BossConfig[.showOnAllDisplays]
        
        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    private func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }

    private func setupDragDetectors() {
        cleanupDragDetectors()

        guard BossConfig[.expandedDragDetection] else { return }

        if BossConfig[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width
        
        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        let detector = DragDetector(notchRegion: notchRegion)
        
        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }
        
        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        if BossConfig[.showOnAllDisplays], let viewModel = viewModels[uuid] {
            viewModel.open()
            coordinator.currentView = .shelf
        } else if !BossConfig[.showOnAllDisplays], let windowScreen = window?.screen, screen == windowScreen {
            vm.open()
            coordinator.currentView = .shelf
        }
    }

    private func createBossAppWindow(for screen: NSScreen, with viewModel: BossViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        let window = BossOverlayWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        
        // Apply the overlay bridge only when the screen is locked
        if isScreenLocked {
            window.activateOverlayBridge()
        } else {
            window.deactivateOverlayBridge()
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes so we can update drag detectors
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setupDragDetectors()
                }
        }
        return window
    }

    @MainActor
    private func targetWindowSize(for viewModel: BossViewModel) -> CGSize {
        guard viewModel.notchState == .open else { return windowSize }

        return CGSize(
            width: windowSize.width,
            height: max(windowSize.height, viewModel.notchSize.height + shadowPadding)
        )
    }

    @MainActor
    private func positionWindow(
        _ window: NSWindow,
        on screen: NSScreen,
        with viewModel: BossViewModel,
        changeAlpha: Bool = false,
        animate: Bool = false
    ) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        let targetSize = targetWindowSize(for: viewModel)
        let targetOrigin = NSPoint(
            x: screenFrame.origin.x + (screenFrame.width / 2) - targetSize.width / 2,
            y: screenFrame.origin.y + screenFrame.height - targetSize.height
        )

        let targetFrame = NSRect(origin: targetOrigin, size: targetSize)

        if animate {
            window.setFrame(targetFrame, display: true, animate: true)
        } else {
            window.setFrame(targetFrame, display: true)
        }
        window.alphaValue = 1
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipboardStateViewModel.shared.startMonitoring()
        ScreenshotStateViewModel.shared.startMonitoring()
        menuBarController.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.clipboardExpansionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncExpandablePanel()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.screenshotsExpansionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncExpandablePanel()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.notesExpansionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncExpandablePanel()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        }

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
                }
        }

        if !BossConfig[.showOnAllDisplays] {
            let viewModel = self.vm
            let window = createBossAppWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
        } else if MusicManager.shared.isNowPlayingDeprecated
            && BossConfig[.mediaController] == .nowPlaying
        {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        previousScreens = NSScreen.screens
    }

    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            DispatchQueue.main.async { [weak self] in
                self?.cleanupWindows()
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        if BossConfig[.showOnAllDisplays] {
            let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

            // Remove windows for screens that no longer exist
            for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows for all screens
            for screen in NSScreen.screens {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = BossViewModel(screenUUID: uuid)
                    let window = createBossAppWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, with: viewModel, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let selectedScreen: NSScreen

            if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
                coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
                selectedScreen = preferredScreen
            } else if BossConfig[.automaticallySwitchDisplay], let mainScreen = NSScreen.main,
                      let mainUUID = mainScreen.displayUUID {
                coordinator.selectedScreenUUID = mainUUID
                selectedScreen = mainScreen
            } else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            vm.screenUUID = selectedScreen.displayUUID
            vm.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

            if window == nil {
                window = createBossAppWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, with: vm, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
        }
    }

    @MainActor
    private func syncExpandablePanel() {
        if BossConfig[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                guard let uuid = screen.displayUUID,
                      let window = windows[uuid],
                      let viewModel = viewModels[uuid]
                else {
                    continue
                }

                withAnimation(.easeInOut(duration: 0.22)) {
                    viewModel.syncOpenNotchSize()
                }
                positionWindow(window, on: screen, with: viewModel, animate: true)
            }
        } else if let window = window {
            let screen = window.screen ?? NSScreen.screen(withUUID: vm.screenUUID ?? "") ?? NSScreen.main

            guard let screen else { return }

            withAnimation(.easeInOut(duration: 0.22)) {
                vm.syncOpenNotchSize()
            }
            positionWindow(window, on: screen, with: vm, animate: true)
        }
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.orderOut(nil)
//                        NSApp.setActivationPolicy(.accessory)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let clipboardExpansionChanged = Notification.Name("ClipboardExpansionChanged")
    static let screenshotsExpansionChanged = Notification.Name("ScreenshotsExpansionChanged")
    static let notesExpansionChanged = Notification.Name("NotesExpansionChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
