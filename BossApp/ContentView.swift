//
//  ContentView.swift
//  Boss App
//
//

import BossConfig
import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BossViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BossViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(
        response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    private var topCornerRadius: CGFloat {
        vm.notchState == .open ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: vm.notchState == .open
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    private var containerMaxHeight: CGFloat {
        max(windowSize.height, vm.notchSize.height + shadowPadding + 8)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: (vm.notchState == .open || isHovering)
                            ? .black.opacity(0.7) : .clear,
                        radius: 6
                    )
                    .padding(
                        .bottom,
                        vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                    )

                mainLayout
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.spring(
                            response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                        let closeAnimation = Animation.spring(
                            response: 0.45, dampingFraction: 1.0, blendDuration: 0)

                        return
                            view
                            .animation(
                                vm.notchState == .open ? openAnimation : closeAnimation,
                                value: vm.notchState)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            SettingsWindowController.shared.showWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: containerMaxHeight, alignment: .top)
        .compositingGroup()
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                vm.close()
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading) {
                if vm.notchState == .closed
                    && (musicManager.isPlaying || !musicManager.isPlayerIdle)
                    && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
                {
                    MusicLiveActivity()
                        .frame(alignment: .center)
                } else if vm.notchState == .open {
                    BossHeader()
                        .frame(height: max(48, vm.effectiveClosedNotchHeight))
                        .padding(.bottom, 0)
                } else {
                    Rectangle().fill(.clear).frame(
                        width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                }
            }
            .zIndex(2)
            if vm.notchState == .open {
                VStack {
                    switch coordinator.currentView {
                    case .home:
                        NotchHomeView(albumArtNamespace: albumArtNamespace)
                    case .shelf:
                        ShelfView()
                    case .clipboard:
                        ClipboardView()
                    case .screenshots:
                        ScreenshotView()
                    case .notes:
                        QuickNotesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(
                    .scale(scale: 0.8, anchor: .top)
                        .combined(with: .opacity)
                        .animation(.smooth(duration: 0.35))
                )
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
            }
        }
        .onDrop(
            of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
            delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                )
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(
                    width: max(0, vm.effectiveClosedNotchHeight - 12),
                    height: max(0, vm.effectiveClosedNotchHeight - 12)
                )

            Rectangle()
                .fill(.black)
                .frame(
                    width: vm.closedNotchSize.width + -cornerRadiusInsets.closed.top
                )

            HStack {
                Rectangle()
                    .fill(
                        BossConfig[.coloredSpectrogram]
                            ? Color(nsColor: musicManager.avgColor).gradient
                            : Color.gray.gradient
                    )
                    .frame(width: 50, alignment: .center)
                    .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                    .mask {
                        AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                            .frame(width: 16, height: 12)
                    }
            }
            .frame(
                width: max(0, vm.effectiveClosedNotchHeight - 12),
                height: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                ),
                alignment: .center
            )
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    var dragDetector: some View {
        if BossConfig[.shelfEnabled] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(
                    of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
                    isTargeted: $vm.dragDetectorTargeting
                ) { providers in
                    vm.dropEvent = true
                    ShelfStateViewModel.shared.load(providers)
                    return true
                }
        } else {
            EmptyView()
        }
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()

        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }

            if vm.notchState == .closed && BossConfig[.enableHaptics] {
                haptics.toggle()
            }

            guard vm.notchState == .closed,
                BossConfig[.openNotchOnHover]
            else { return }

            hoverTask = Task {
                try? await Task.sleep(for: .seconds(BossConfig[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.vm.notchState == .closed,
                        self.isHovering
                    else { return }

                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }

                    if self.vm.notchState == .open {
                        self.vm.close()
                    }
                }
            }
        }
    }

}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

private struct QuickNoteItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var isPinned: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(), title: String = "", body: String = "", isPinned: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        if let firstLine =
            trimmedBody
            .split(whereSeparator: \.isNewline)
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
        {
            return firstLine
        }

        return "Untitled"
    }

    var previewText: String {
        let bodyLines =
            trimmedBody
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if bodyLines.count > 1 {
            return bodyLines[1]
        }

        return bodyLines.first ?? "Empty note"
    }

    var isEffectivelyEmpty: Bool {
        trimmedTitle.isEmpty && trimmedBody.isEmpty
    }

    var relativeTimestamp: String {
        QuickNotesFormatters.relative.localizedString(for: updatedAt, relativeTo: .now)
    }
}

private struct QuickNotesStore: Codable {
    var items: [QuickNoteItem]
    var selectedNoteID: UUID?
}

private enum QuickNotesFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

private final class QuickNotesPersistenceService {
    static let shared = QuickNotesPersistenceService()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let fileManager = FileManager.default
        let support = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (support ?? fileManager.temporaryDirectory)
            .appendingPathComponent("BossApp", isDirectory: true)
            .appendingPathComponent("QuickNotes", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        fileURL = directory.appendingPathComponent("notes.json")
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> QuickNotesStore {
        guard let data = try? Data(contentsOf: fileURL) else {
            return QuickNotesStore(items: [], selectedNoteID: nil)
        }

        return (try? decoder.decode(QuickNotesStore.self, from: data))
            ?? QuickNotesStore(items: [], selectedNoteID: nil)
    }

    func save(_ store: QuickNotesStore) {
        do {
            let data = try encoder.encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save quick notes: \(error.localizedDescription)")
        }
    }
}

@MainActor
private final class QuickNotesStateViewModel: ObservableObject {
    static let shared = QuickNotesStateViewModel()

    @Published private(set) var items: [QuickNoteItem] = [] {
        didSet {
            scheduleSave()
        }
    }

    @Published var selectedNoteID: UUID? {
        didSet {
            scheduleSave()
        }
    }

    private let maxItems = 50
    private var saveTask: Task<Void, Never>?

    private init() {
        let store = QuickNotesPersistenceService.shared.load()
        items = store.items.sorted { $0.updatedAt > $1.updatedAt }
        selectedNoteID = nil
    }

    deinit {
        saveTask?.cancel()
    }

    var selectedNote: QuickNoteItem? {
        guard let selectedNoteID else { return nil }
        return items.first(where: { $0.id == selectedNoteID })
    }

    func createNote() {
        pruneEmptyNotes(excluding: selectedNoteID)

        let note = QuickNoteItem()
        items.insert(note, at: 0)
        selectedNoteID = note.id
        trimOverflow()
    }

    func select(_ item: QuickNoteItem) {
        selectedNoteID = item.id
    }

    func updateSelectedTitle(_ title: String) {
        guard let index = selectedIndex else { return }
        guard items[index].title != title else { return }

        items[index].title = title
        items[index].updatedAt = .now
        resortAndReselect()
    }

    func updateSelectedBody(_ body: String) {
        guard let index = selectedIndex else { return }
        guard items[index].body != body else { return }

        items[index].body = body
        items[index].updatedAt = .now
        resortAndReselect()
    }

    func deleteSelected() {
        guard let selectedNoteID else { return }

        items.removeAll { $0.id == selectedNoteID }
        self.selectedNoteID = nil
    }

    private var selectedIndex: Int? {
        if let selectedNoteID,
            let index = items.firstIndex(where: { $0.id == selectedNoteID })
        {
            return index
        }

        return nil
    }

    private func resortAndReselect() {
        let currentID = selectedNoteID
        items.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        selectedNoteID = currentID
    }

    func togglePin(_ item: QuickNoteItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        resortAndReselect()
    }

    func delete(_ item: QuickNoteItem) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            items.removeAll { $0.id == item.id }
            if selectedNoteID == item.id { selectedNoteID = nil }
        }
    }

    func copyText(_ item: QuickNoteItem) {
        let text = [item.title, item.body]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func trimOverflow() {
        guard items.count > maxItems else { return }
        items = Array(items.prefix(maxItems))
        if selectedNoteID != nil && !items.contains(where: { $0.id == selectedNoteID }) {
            selectedNoteID = nil
        }
    }

    private func pruneEmptyNotes(excluding id: UUID?) {
        items.removeAll { note in
            note.id != id && note.isEffectivelyEmpty
        }
    }

    private func scheduleSave() {
        let snapshot = QuickNotesStore(items: items, selectedNoteID: selectedNoteID)
        saveTask?.cancel()
        saveTask = Task { [snapshot] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            QuickNotesPersistenceService.shared.save(snapshot)
        }
    }
}

@MainActor
final class ScreenshotStateViewModel: ObservableObject {
    static let shared = ScreenshotStateViewModel()

    private let screenshotFolderURLKey = "screenshotFolderURL"
    private let screenshotFolderBookmarkKey = "screenshotFolderBookmark"

    @Published private(set) var items: [ScreenshotItem] = []

    var isEmpty: Bool { items.isEmpty }

    private let maxItems = 100
    private var monitorTask: Task<Void, Never>?

    private init() {
        // Don't reload here - let startMonitoring() handle it
    }

    deinit {
        monitorTask?.cancel()
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        reload()

        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    self.reload()
                }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func reload() {
        Task { @MainActor in
            let customFolder = resolveCustomFolderURL()

            let items: [ScreenshotItem]

            if let folderURL = customFolder {
                let paths = await XPCHelperClient.shared.getScreenshotPaths(
                    inFolder: folderURL.path,
                    limit: maxItems
                )
                var seen = Set<String>()
                let uniquePaths = paths.filter { path in
                    if seen.contains(path) {
                        return false
                    }
                    seen.insert(path)
                    return true
                }
                items = uniquePaths.compactMap { urlPath -> ScreenshotItem? in
                    let url = URL(fileURLWithPath: urlPath)
                    return ScreenshotItem(url: url)
                }
            } else {
                // Use XPCHelperClient for default location
                let paths = await XPCHelperClient.shared.getScreenshotPaths(limit: maxItems)
                // Remove duplicates while preserving order
                var seen = Set<String>()
                let uniquePaths = paths.filter { path in
                    if seen.contains(path) {
                        return false
                    }
                    seen.insert(path)
                    return true
                }
                items = uniquePaths.compactMap { urlPath -> ScreenshotItem? in
                    let url = URL(fileURLWithPath: urlPath)
                    return ScreenshotItem(url: url)
                }
            }

            self.items = items
        }
    }

    func open(_ item: ScreenshotItem) {
        Task {
            let openedByHelper = await XPCHelperClient.shared.openFile(path: item.url.path)
            guard !openedByHelper else { return }

            await MainActor.run {
                _ = self.withScopedAccess(for: item) {
                    guard FileManager.default.fileExists(atPath: item.url.path) else {
                        return false
                    }
                    return NSWorkspace.shared.open(item.url)
                }
            }
        }
    }

    func reveal(_ item: ScreenshotItem) {
        Task {
            let revealedByHelper = await XPCHelperClient.shared.revealFile(path: item.url.path)
            guard !revealedByHelper else { return }

            await MainActor.run {
                _ = self.withScopedAccess(for: item) {
                    guard FileManager.default.fileExists(atPath: item.url.path) else {
                        return false
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    return true
                }
            }
        }
    }

    func copy(_ item: ScreenshotItem) {
        Task {
            guard let data = await XPCHelperClient.shared.readFileData(path: item.url.path),
                let image = NSImage(data: data)
            else {
                await MainActor.run {
                    _ = self.withScopedAccess(for: item) {
                        guard FileManager.default.fileExists(atPath: item.url.path) else {
                            return false
                        }
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()

                        if let localImage = NSImage(contentsOf: item.url) {
                            pasteboard.writeObjects([localImage])
                        } else {
                            pasteboard.writeObjects([item.url as NSURL])
                        }
                        return true
                    }
                }
                return
            }

            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            }
        }
    }

    func delete(_ item: ScreenshotItem) {
        Task {
            let deletedByHelper = await XPCHelperClient.shared.trashFile(path: item.url.path)
            if deletedByHelper {
                await MainActor.run { self.reload() }
                return
            }

            await MainActor.run {
                let deletedLocally = self.withScopedAccess(for: item) {
                    guard FileManager.default.fileExists(atPath: item.url.path) else {
                        return false
                    }
                    do {
                        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                        return true
                    } catch {
                        do {
                            try FileManager.default.removeItem(at: item.url)
                            return true
                        } catch {
                            return false
                        }
                    }
                }

                if deletedLocally {
                    self.reload()
                }
            }
        }
    }

    private func resolveCustomFolderURL() -> URL? {
        if let bookmarkData = UserDefaults.standard.data(forKey: screenshotFolderBookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }

        if let data = UserDefaults.standard.data(forKey: screenshotFolderURLKey),
            let nsurl = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data)
        {
            return nsurl as URL
        }

        return nil
    }

    private func withScopedAccess<T>(for item: ScreenshotItem, _ body: () -> T) -> T {
        guard let folderURL = resolveCustomFolderURL(),
            item.url.path.hasPrefix(folderURL.path)
        else {
            return body()
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        return body()
    }

    private static func loadScreenshotItems(limit: Int) -> [ScreenshotItem] {
        // Now handled by XPC Helper - this is deprecated
        return []
    }

}

struct ScreenshotItem: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let fileSize: Int?

    var id: String { url.path }

    init?(url: URL) {
        let lowercasedExtension = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "tiff", "heic", "gif", "webp"].contains(lowercasedExtension)
        else {
            return nil
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        guard Self.matchesScreenshotName(fileName) else {
            return nil
        }

        let resourceValues = try? url.resourceValues(forKeys: [
            .creationDateKey,
            .contentModificationDateKey,
            .isRegularFileKey,
            .fileSizeKey,
        ])

        guard resourceValues?.isRegularFile == true else { return nil }

        self.url = url
        self.createdAt =
            resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? .distantPast
        self.fileSize = resourceValues?.fileSize
    }

    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    var subtitle: String {
        if let fileSize {
            return
                "\(relativeTimestamp) • \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))"
        }
        return relativeTimestamp
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: .now)
    }

    private static func matchesScreenshotName(_ name: String) -> Bool {
        let normalized = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let prefixes = [
            "screen shot",
            "screenshot",
            "ekran resmi",
            "ekran goruntusu",
            "ekran goruntuleri",
            "ekran goruntusu",
            "ekran goruntusu",
            "ekran görüntüsü",
            "ekran görüntüleri",
        ]

        return prefixes.contains { normalized.hasPrefix($0) }
    }
}

private struct ScreenshotView: View {
    @EnvironmentObject var vm: BossViewModel
    @ObservedObject private var coordinator = BossViewCoordinator.shared
    @ObservedObject private var screenshots = ScreenshotStateViewModel.shared

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay {
                content
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                print("📸 ScreenshotView appeared")
                screenshots.startMonitoring()
            }
            .onDisappear {
                print("📸 ScreenshotView disappeared")
                screenshots.stopMonitoring()
            }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if screenshots.isEmpty {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 80, height: 60)
                        .overlay {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    Text("Screenshots")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(screenshots.items) { item in
                            ScreenshotRowView(
                                item: item,
                                onOpen: { screenshots.open(item) },
                                onReveal: { screenshots.reveal(item) },
                                onCopy: { screenshots.copy(item) },
                                onDelete: { screenshots.delete(item) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            Button {
                coordinator.toggleScreenshotsExpanded()
            } label: {
                Image(
                    systemName: coordinator.isScreenshotsExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right"
                )
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(coordinator.isScreenshotsExpanded ? "Collapse screenshots" : "Expand screenshots")
        }
    }
}

private struct ScreenshotRowView: View {
    let item: ScreenshotItem
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            preview

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                actionButton(systemName: "arrow.up.forward.app", action: onOpen)
                actionButton(systemName: "folder", action: onReveal)
                actionButton(systemName: "doc.on.doc", action: onCopy)
                actionButton(systemName: "trash", action: onDelete)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isHovering ? 0.09 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(isHovering ? 0.1 : 0.05), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let image = NSImage(contentsOf: item.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.06))
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func actionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickNotesView: View {
    @EnvironmentObject var vm: BossViewModel
    @ObservedObject private var coordinator = BossViewCoordinator.shared
    @StateObject private var notes = QuickNotesStateViewModel.shared
    @FocusState private var bodyFocused: Bool

    private var selectedNote: QuickNoteItem? { notes.selectedNote }

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay {
                content
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if let note = selectedNote {
                editorView(note: note)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .scale(scale: 0.92).combined(with: .opacity)
                        ))
            } else {
                gridView
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .scale(scale: 0.92).combined(with: .opacity)
                        ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.36, dampingFraction: 0.80), value: selectedNote?.id)
        .overlay(alignment: .topTrailing) {
            if selectedNote == nil {
                HStack(spacing: 8) {
                    Button {
                        newNote()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("New note")

                    Button {
                        coordinator.toggleNotesExpanded()
                    } label: {
                        Image(
                            systemName: coordinator.isNotesExpanded
                                ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right"
                        )
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help(coordinator.isNotesExpanded ? "Küçült" : "Büyüt")
                }
            }
        }
    }

    // ── Grid ──────────────────────────────────────────────────────────
    @ViewBuilder
    private var gridView: some View {
        Group {
            if notes.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                    Text("No notes yet")
                        .foregroundStyle(.gray)
                        .font(.system(.callout, design: .rounded))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    let cols = [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 10)]
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(notes.items) { item in
                            PostItChip(item: item) {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                    notes.selectedNoteID = item.id
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    bodyFocused = true
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Editor ────────────────────────────────────────────────────────
    @ViewBuilder
    private func editorView(note: QuickNoteItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    close()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PostItStyle.ink.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        bodyFocused = false
                        notes.deleteSelected()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            TextField(
                "Title",
                text: Binding(
                    get: { notes.selectedNote?.title ?? note.title },
                    set: { notes.updateSelectedTitle($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(PostItStyle.ink)
            .padding(.horizontal, 14)
            .padding(.top, 2)

            Divider().padding(.horizontal, 12).padding(.vertical, 5).opacity(0.3)

            ZStack(alignment: .topLeading) {
                let previewBody = notes.selectedNote?.body ?? note.body
                if previewBody.isEmpty {
                    Text("Write something...")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(PostItStyle.ink.opacity(0.40))
                        .padding(.horizontal, 17).padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(
                    text: Binding(
                        get: { notes.selectedNote?.body ?? note.body },
                        set: { notes.updateSelectedBody($0) }
                    )
                )
                .scrollContentBackground(.hidden)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(PostItStyle.ink)
                .focused($bodyFocused)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Text(notes.selectedNote?.relativeTimestamp ?? note.relativeTimestamp)
                Spacer()
                Text("\(notes.selectedNote?.body.count ?? note.body.count) chars")
            }
            .foregroundStyle(PostItStyle.ink.opacity(0.45))
            .font(.system(size: 10, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PostItStyle.paper)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            PostItCorner(size: 24).padding(.top, 1).padding(.trailing, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 22, y: 10)
        .padding(6)
    }

    // ── Helpers ───────────────────────────────────────────────────────
    private func newNote() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            notes.createNote()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            bodyFocused = true
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
            bodyFocused = false
            notes.selectedNoteID = nil
        }
    }

    @ViewBuilder
    private func iconCircle(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(0.10)))
    }
}

// MARK: - Post-it chip

private struct PostItChip: View {
    let item: QuickNoteItem
    let onSelect: () -> Void
    @StateObject private var notes = QuickNotesStateViewModel.shared

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                            .foregroundStyle(PostItStyle.ink)
                        Spacer(minLength: 0)
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.yellow.opacity(0.85))
                                .rotationEffect(.degrees(45))
                        }
                    }
                    Spacer(minLength: 0)
                    Text(item.previewText)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(PostItStyle.ink.opacity(0.60))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Text(item.relativeTimestamp)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(PostItStyle.ink.opacity(0.38))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }
            .frame(
                minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 100,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PostItStyle.paper)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                PostItCorner(size: 16).padding(.top, 1).padding(.trailing, 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        item.isPinned ? Color.yellow.opacity(0.35) : Color.white.opacity(0.10),
                        lineWidth: item.isPinned ? 1.2 : 1
                    )
            }
            .shadow(color: PostItStyle.shadow.opacity(0.65), radius: 8, y: 5)
            .rotationEffect(.degrees(chipAngle))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                notes.togglePin(item)
            } label: {
                Label(
                    item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                    notes.delete(item)
                }
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private var chipAngle: Double {
        if item.isPinned { return 0 }
        let bucket = abs(item.id.uuidString.hashValue % 5)
        let angles: [Double] = [-2.0, -0.8, 0, 1.2, 2.5]
        return angles[bucket]
    }
}

// MARK: - Design tokens

private enum PostItStyle {
    static let ink = Color.white.opacity(0.90)
    static let paper = LinearGradient(
        colors: [Color(white: 0.13), Color(white: 0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let shadow = Color.black.opacity(0.50)
    static let fold = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

private struct PostItCorner: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack(alignment: .topTrailing) {
            PostItFold().fill(PostItStyle.fold)
            PostItFold().stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        }
        .frame(width: size, height: size)
    }
}

private struct PostItFold: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    let vm = BossViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
