import AppKit
import Foundation

struct ClipboardRepresentation: Codable, Hashable {
    let typeIdentifier: String
    let data: Data

    var pasteboardType: NSPasteboard.PasteboardType {
        NSPasteboard.PasteboardType(typeIdentifier)
    }
}

enum ClipboardPrimaryKind: String, Codable, Hashable {
    case text
    case richText
    case image
    case files
    case mixed
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var representations: [ClipboardRepresentation]
    var sourceBundleIdentifier: String?
    var sourceApplicationName: String?
    var copiedAt: Date
    var firstCopiedAt: Date
    var copyCount: Int
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        representations: [ClipboardRepresentation],
        title: String? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceApplicationName: String? = nil,
        copiedAt: Date = .now,
        firstCopiedAt: Date? = nil,
        copyCount: Int = 1,
        isPinned: Bool = false
    ) {
        let normalizedRepresentations = Self.normalizedRepresentations(from: representations)
        self.id = id
        self.representations = normalizedRepresentations
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceApplicationName = sourceApplicationName
        self.copiedAt = copiedAt
        self.firstCopiedAt = firstCopiedAt ?? copiedAt
        self.copyCount = copyCount
        self.isPinned = isPinned
        self.title = Self.resolvedTitle(preferred: title, representations: normalizedRepresentations)
    }

    var identityKey: String {
        Self.stableDigest(for: representations)
    }

    var primaryKind: ClipboardPrimaryKind {
        let hasFiles = !fileURLs.isEmpty
        let hasImage = imageData != nil
        let hasPlainText = plainText != nil
        let hasStyledText = rtfData != nil || htmlData != nil

        if hasFiles && !hasImage && !hasPlainText && !hasStyledText {
            return .files
        }

        if hasImage && !hasFiles && !hasPlainText && !hasStyledText {
            return .image
        }

        if hasImage || hasFiles {
            return .mixed
        }

        if hasStyledText && !hasPlainText {
            return .richText
        }

        return .text
    }

    var plainText: String? {
        if let stringData = data(for: NSPasteboard.PasteboardType.string.rawValue),
           let string = String(data: stringData, encoding: .utf8),
           let cleaned = Self.cleanedText(string)
        {
            return cleaned
        }

        if let rtfData,
           let attributed = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ),
           let cleaned = Self.cleanedText(attributed.string)
        {
            return cleaned
        }

        if let htmlData,
           let attributed = try? NSAttributedString(
               data: htmlData,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ),
           let cleaned = Self.cleanedText(attributed.string)
        {
            return cleaned
        }

        return nil
    }

    var rtfData: Data? {
        data(for: NSPasteboard.PasteboardType.rtf.rawValue)
    }

    var htmlData: Data? {
        data(for: NSPasteboard.PasteboardType.html.rawValue)
    }

    var imageData: Data? {
        if let pngData = data(for: NSPasteboard.PasteboardType.png.rawValue) {
            return pngData
        }

        if let tiffData = data(for: NSPasteboard.PasteboardType.tiff.rawValue) {
            return tiffData
        }

        return representations.first(where: { Self.isImageType($0.typeIdentifier) })?.data
    }

    var image: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }

    var fileURLs: [URL] {
        representations
            .filter { $0.typeIdentifier == NSPasteboard.PasteboardType.fileURL.rawValue }
            .compactMap { representation in
                guard let string = String(data: representation.data, encoding: .utf8) else { return nil }
                if let url = URL(string: string), url.isFileURL {
                    return url
                }
                return URL(fileURLWithPath: string)
            }
    }

    var previewText: String {
        if let plainText {
            return plainText
        }

        if !fileURLs.isEmpty {
            if fileURLs.count == 1, let fileURL = fileURLs.first {
                return fileURL.path
            }
            return "\(fileURLs.count) files ready to paste again."
        }

        if imageData != nil {
            return hasStyledText ? "Image and styled content" : "Image copied from your clipboard."
        }

        if hasStyledText {
            return "Styled content ready to paste again."
        }

        return "Clipboard item"
    }

    var detailText: String {
        switch primaryKind {
        case .text:
            return "Text"
        case .richText:
            return "Rich text"
        case .image:
            return "Image"
        case .files:
            return fileURLs.count == 1 ? "File" : "\(fileURLs.count) files"
        case .mixed:
            var components: [String] = []
            if imageData != nil {
                components.append("Image")
            }
            if !fileURLs.isEmpty {
                components.append(fileURLs.count == 1 ? "File" : "\(fileURLs.count) files")
            }
            if hasStyledText || plainText != nil {
                components.append(hasStyledText ? "Styled text" : "Text")
            }
            return components.isEmpty ? "Mixed" : components.joined(separator: " + ")
        }
    }

    var iconName: String {
        switch primaryKind {
        case .text:
            return "text.alignleft"
        case .richText:
            return "doc.richtext"
        case .image:
            return "photo"
        case .files:
            return "doc.on.doc"
        case .mixed:
            return "square.stack.3d.up.fill"
        }
    }

    var kindBadgeText: String {
        switch primaryKind {
        case .text:
            return "Text"
        case .richText:
            return "Rich"
        case .image:
            return "Image"
        case .files:
            return fileURLs.count == 1 ? "File" : "Files"
        case .mixed:
            return "Mixed"
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: copiedAt, relativeTo: .now)
    }

    var searchableText: String {
        var parts: [String] = [title, previewText, detailText]

        if let plainText {
            parts.append(plainText)
        }

        parts.append(contentsOf: fileURLs.map(\.lastPathComponent))

        if let sourceApplicationName {
            parts.append(sourceApplicationName)
        }

        return parts.joined(separator: "\n")
    }

    var hasStyledText: Bool {
        rtfData != nil || htmlData != nil
    }

    func matches(query: String) -> Bool {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        guard !normalizedQuery.isEmpty else { return true }

        return searchableText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .contains(normalizedQuery)
    }

    func registeringCopy(at date: Date) -> ClipboardItem {
        ClipboardItem(
            id: id,
            representations: representations,
            title: title,
            sourceBundleIdentifier: sourceBundleIdentifier,
            sourceApplicationName: sourceApplicationName,
            copiedAt: date,
            firstCopiedAt: firstCopiedAt,
            copyCount: copyCount + 1,
            isPinned: isPinned
        )
    }

    private func data(for typeIdentifier: String) -> Data? {
        representations.first(where: { $0.typeIdentifier == typeIdentifier })?.data
    }

    private static func normalizedRepresentations(from representations: [ClipboardRepresentation]) -> [ClipboardRepresentation] {
        var unique: [ClipboardRepresentation] = []
        var seen = Set<ClipboardRepresentation>()

        for representation in representations where !representation.data.isEmpty {
            if seen.insert(representation).inserted {
                unique.append(representation)
            }
        }

        return unique
    }

    private static func resolvedTitle(preferred: String?, representations: [ClipboardRepresentation]) -> String {
        if let preferred,
           let cleaned = cleanedText(preferred)
        {
            return String(cleaned.prefix(120))
        }

        let item = ClipboardItem(
            id: UUID(),
            representations: representations,
            title: "",
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil,
            copiedAt: .now,
            firstCopiedAt: .now,
            copyCount: 1,
            isPinned: false,
            bypassTitleResolution: true
        )

        if let plainText = item.plainText {
            return String(plainText.prefix(120))
        }

        if !item.fileURLs.isEmpty {
            if item.fileURLs.count == 1, let fileURL = item.fileURLs.first {
                return fileURL.lastPathComponent
            }
            return "\(item.fileURLs.count) files"
        }

        if item.imageData != nil {
            return item.hasStyledText ? "Image and text" : "Image"
        }

        if item.hasStyledText {
            return "Rich text"
        }

        return "Clipboard item"
    }

    private init(
        id: UUID,
        representations: [ClipboardRepresentation],
        title: String,
        sourceBundleIdentifier: String?,
        sourceApplicationName: String?,
        copiedAt: Date,
        firstCopiedAt: Date,
        copyCount: Int,
        isPinned: Bool,
        bypassTitleResolution: Bool
    ) {
        self.id = id
        self.representations = Self.normalizedRepresentations(from: representations)
        self.title = bypassTitleResolution ? title : Self.resolvedTitle(preferred: title, representations: representations)
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceApplicationName = sourceApplicationName
        self.copiedAt = copiedAt
        self.firstCopiedAt = firstCopiedAt
        self.copyCount = copyCount
        self.isPinned = isPinned
    }

    private static func cleanedText(_ string: String) -> String? {
        let cleaned = string
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        return cleaned
    }

    private static func stableDigest(for representations: [ClipboardRepresentation]) -> String {
        var hash: UInt64 = 0xcbf29ce484222325

        let sortedRepresentations = representations.sorted { lhs, rhs in
            if lhs.typeIdentifier != rhs.typeIdentifier {
                return lhs.typeIdentifier < rhs.typeIdentifier
            }
            return lhs.data.lexicographicallyPrecedes(rhs.data)
        }

        for representation in sortedRepresentations {
            for byte in representation.typeIdentifier.utf8 {
                hash ^= UInt64(byte)
                hash &*= 0x100000001b3
            }

            hash ^= 0xff
            hash &*= 0x100000001b3

            for byte in representation.data {
                hash ^= UInt64(byte)
                hash &*= 0x100000001b3
            }

            hash ^= 0xfe
            hash &*= 0x100000001b3
        }

        return String(hash, radix: 16)
    }

    private static func isImageType(_ typeIdentifier: String) -> Bool {
        let lowercased = typeIdentifier.lowercased()
        return lowercased.contains("png")
            || lowercased.contains("tiff")
            || lowercased.contains("jpeg")
            || lowercased.contains("jpg")
            || lowercased.contains("gif")
            || lowercased.contains("heic")
            || lowercased.contains("bmp")
            || lowercased.contains("webp")
            || lowercased.contains("image")
    }
}

extension ClipboardItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case representations
        case sourceBundleIdentifier
        case sourceApplicationName
        case copiedAt
        case firstCopiedAt
        case copyCount
        case isPinned
        case payload
        case identityKey
    }

    private struct LegacyPayload: Decodable {
        let kind: String
        let text: String?
        let image: Data?
        let files: [String]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let sourceBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceBundleIdentifier)
        let sourceApplicationName = try container.decodeIfPresent(String.self, forKey: .sourceApplicationName)
        let copiedAt = try container.decodeIfPresent(Date.self, forKey: .copiedAt) ?? .now
        let firstCopiedAt = try container.decodeIfPresent(Date.self, forKey: .firstCopiedAt) ?? copiedAt
        let copyCount = try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1
        let isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false

        let representations: [ClipboardRepresentation]
        if let decodedRepresentations = try container.decodeIfPresent([ClipboardRepresentation].self, forKey: .representations) {
            representations = decodedRepresentations
        } else if let payload = try container.decodeIfPresent(LegacyPayload.self, forKey: .payload) {
            switch payload.kind {
            case "text":
                if let text = payload.text {
                    representations = [
                        ClipboardRepresentation(
                            typeIdentifier: NSPasteboard.PasteboardType.string.rawValue,
                            data: Data(text.utf8)
                        )
                    ]
                } else {
                    representations = []
                }
            case "image":
                if let image = payload.image {
                    representations = [
                        ClipboardRepresentation(
                            typeIdentifier: NSPasteboard.PasteboardType.tiff.rawValue,
                            data: image
                        )
                    ]
                } else {
                    representations = []
                }
            case "files":
                let files = payload.files ?? []
                representations = files.map { path in
                    ClipboardRepresentation(
                        typeIdentifier: NSPasteboard.PasteboardType.fileURL.rawValue,
                        data: Data(URL(fileURLWithPath: path).absoluteString.utf8)
                    )
                }
            default:
                representations = []
            }
        } else {
            representations = []
        }

        self = ClipboardItem(
            id: id,
            representations: representations,
            title: try container.decodeIfPresent(String.self, forKey: .title),
            sourceBundleIdentifier: sourceBundleIdentifier,
            sourceApplicationName: sourceApplicationName,
            copiedAt: copiedAt,
            firstCopiedAt: firstCopiedAt,
            copyCount: copyCount,
            isPinned: isPinned
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(representations, forKey: .representations)
        try container.encodeIfPresent(sourceBundleIdentifier, forKey: .sourceBundleIdentifier)
        try container.encodeIfPresent(sourceApplicationName, forKey: .sourceApplicationName)
        try container.encode(copiedAt, forKey: .copiedAt)
        try container.encode(firstCopiedAt, forKey: .firstCopiedAt)
        try container.encode(copyCount, forKey: .copyCount)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(identityKey, forKey: .identityKey)
    }
}
