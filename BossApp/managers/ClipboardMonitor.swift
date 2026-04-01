import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    var onNewCapture: ((ClipboardItem) -> Void)?

    private let pasteboard = NSPasteboard.general
    private let markerType = NSPasteboard.PasteboardType("com.bossapp.clipboard-history")
    private var timer: Timer?
    private var changeCount: Int
    private let ignoredTypePrefixes = [
        "com.bossapp.clipboard-history",
        "de.petermaurer.TransientPasteboardType",
        "com.typeit4me.clipping",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.ConcealedType",
    ]

    private init() {
        changeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
        timer?.tolerance = 0.1
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        var pasteboardItems: [NSPasteboardItem] = []

        let nonFileRepresentations = item.representations.filter {
            $0.typeIdentifier != NSPasteboard.PasteboardType.fileURL.rawValue
        }

        if !nonFileRepresentations.isEmpty {
            let richItem = NSPasteboardItem()

            for representation in nonFileRepresentations {
                richItem.setData(representation.data, forType: representation.pasteboardType)
            }

            if richItem.types.contains(.string) == false,
                let plainText = item.plainText
            {
                richItem.setString(plainText, forType: .string)
            }

            pasteboardItems.append(richItem)
        }

        for fileURL in item.fileURLs {
            let fileItem = NSPasteboardItem()
            fileItem.setString(fileURL.absoluteString, forType: .fileURL)
            pasteboardItems.append(fileItem)
        }

        if pasteboardItems.isEmpty {
            pasteboardItems.append(NSPasteboardItem())
        }

        pasteboardItems[0].setString("1", forType: markerType)

        pasteboard.clearContents()
        pasteboard.writeObjects(pasteboardItems as [NSPasteboardWriting])
        changeCount = pasteboard.changeCount
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        if pasteboard.pasteboardItems?.contains(where: { $0.types.contains(markerType) }) == true {
            return
        }

        guard let item = makeClipboardItem() else { return }
        onNewCapture?(item)
    }

    private func makeClipboardItem() -> ClipboardItem? {
        guard let pasteboardItems = pasteboard.pasteboardItems,
            !pasteboardItems.isEmpty
        else {
            return nil
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        var capturedRepresentations: [ClipboardRepresentation] = []

        for pasteboardItem in pasteboardItems {
            capturedRepresentations.append(contentsOf: representations(from: pasteboardItem))
        }

        guard !capturedRepresentations.isEmpty else { return nil }

        return ClipboardItem(
            representations: capturedRepresentations,
            sourceBundleIdentifier: sourceApp?.bundleIdentifier,
            sourceApplicationName: sourceApp?.localizedName
        )
    }

    private func representations(from item: NSPasteboardItem) -> [ClipboardRepresentation] {
        prioritizedTypes(for: item).compactMap { type in
            representation(from: item, type: type)
        }
    }

    private func prioritizedTypes(for item: NSPasteboardItem) -> [NSPasteboard.PasteboardType] {
        item.types
            .filter { isSupportedType($0) }
            .sorted { lhs, rhs in
                priority(for: lhs) < priority(for: rhs)
            }
    }

    private func representation(
        from item: NSPasteboardItem,
        type: NSPasteboard.PasteboardType
    ) -> ClipboardRepresentation? {
        if type == .fileURL,
            let string = item.string(forType: type)
        {
            return ClipboardRepresentation(
                typeIdentifier: type.rawValue,
                data: Data(string.utf8)
            )
        }

        if isPlainTextType(type),
            let string = item.string(forType: type)
        {
            return ClipboardRepresentation(
                typeIdentifier: NSPasteboard.PasteboardType.string.rawValue,
                data: Data(string.utf8)
            )
        }

        if let data = item.data(forType: type), !data.isEmpty {
            return ClipboardRepresentation(
                typeIdentifier: type.rawValue,
                data: data
            )
        }

        if let string = item.string(forType: type) {
            return ClipboardRepresentation(
                typeIdentifier: type.rawValue,
                data: Data(string.utf8)
            )
        }

        return nil
    }

    private func isSupportedType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let rawValue = type.rawValue

        if ignoredTypePrefixes.contains(where: { rawValue.hasPrefix($0) }) {
            return false
        }

        if type == .string || type == .rtf || type == .html || type == .fileURL {
            return true
        }

        if isPlainTextType(type) || isImageType(type) {
            return true
        }

        return rawValue.hasPrefix("public.")
    }

    private func isPlainTextType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let rawValue = type.rawValue
        return rawValue == NSPasteboard.PasteboardType.string.rawValue
            || rawValue == "public.utf8-plain-text"
            || rawValue == "public.utf16-plain-text"
            || rawValue == "NSStringPboardType"
    }

    private func isImageType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let rawValue = type.rawValue.lowercased()
        return rawValue.contains("png")
            || rawValue.contains("tiff")
            || rawValue.contains("jpeg")
            || rawValue.contains("jpg")
            || rawValue.contains("gif")
            || rawValue.contains("heic")
            || rawValue.contains("bmp")
            || rawValue.contains("webp")
            || rawValue.contains("image")
    }

    private func priority(for type: NSPasteboard.PasteboardType) -> Int {
        switch type {
        case .fileURL:
            return 0
        case .string:
            return 1
        case .rtf:
            return 2
        case .html:
            return 3
        default:
            if isImageType(type) {
                return 4
            }
            return 10
        }
    }
}
