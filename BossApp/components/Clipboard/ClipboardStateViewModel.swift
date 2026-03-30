import Foundation

@MainActor
final class ClipboardStateViewModel: ObservableObject {
    static let shared = ClipboardStateViewModel()

    @Published var searchQuery: String = ""
    @Published private(set) var items: [ClipboardItem] = [] {
        didSet { ClipboardPersistenceService.shared.save(items) }
    }

    var isEmpty: Bool { items.isEmpty }
    var filteredItems: [ClipboardItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { $0.matches(query: query) }
    }

    private let maxUnpinnedItems = 100

    private init() {
        items = ClipboardPersistenceService.shared.load()
        sortItems()
        ClipboardMonitor.shared.onNewCapture = { [weak self] item in
            self?.capture(item)
        }
    }

    func startMonitoring() {
        ClipboardMonitor.shared.start()
    }

    func stopMonitoring() {
        ClipboardMonitor.shared.stop()
    }

    func capture(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.identityKey == item.identityKey }) {
            var existing = items.remove(at: index)
            existing = existing.registeringCopy(at: item.copiedAt)
            if existing.sourceApplicationName == nil {
                existing.sourceApplicationName = item.sourceApplicationName
                existing.sourceBundleIdentifier = item.sourceBundleIdentifier
            }
            if existing.title == "Clipboard item" && item.title != "Clipboard item" {
                existing.title = item.title
            }
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }

        sortItems()
        trimOverflow()
    }

    func copy(_ item: ClipboardItem) {
        ClipboardMonitor.shared.copyToPasteboard(item)
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }

    private func sortItems() {
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.copiedAt > rhs.copiedAt
        }
    }

    private func trimOverflow() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > maxUnpinnedItems else { return }
        let overflowIDs = Set(unpinned.dropFirst(maxUnpinnedItems).map(\.id))
        items.removeAll { overflowIDs.contains($0.id) }
    }
}
