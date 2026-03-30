//
//  MusicControlButton.swift
//  Boss App
//
//

import BossConfig

enum MusicControlButton: String, CaseIterable, Identifiable, Codable, BossConfig.Serializable {
    case shuffle
    case previous
    case playPause
    case next
    case repeatMode
    case volume
    case favorite
    case goBackward
    case goForward
    case none

    var id: String { rawValue }

    static let defaultLayout: [MusicControlButton] = [
        .none,
        .previous,
        .playPause,
        .next,
        .none
    ]

    static let minSlotCount: Int = 3
    static let maxSlotCount: Int = 5

    static let pickerOptions: [MusicControlButton] = [
        .shuffle,
        .previous,
        .playPause,
        .next,
        .repeatMode,
        .favorite,
        .volume,
        .goBackward,
        .goForward
    ]

    var label: String {
        switch self {
        case .shuffle:
            return "Karıştır"
        case .previous:
            return "Önceki"
        case .playPause:
            return "Oynat/Duraklat"
        case .next:
            return "Sonraki"
        case .repeatMode:
            return "Tekrarla"
        case .volume:
            return "Ses"
        case .favorite:
            return "Favori"
        case .goBackward:
            return "Geri 15s"
        case .goForward:
            return "İleri 15s"
        case .none:
            return "Boş yuva"
        }
    }

    var iconName: String {
        switch self {
        case .shuffle:
            return "shuffle"
        case .previous:
            return "backward.fill"
        case .playPause:
            return "playpause"
        case .next:
            return "forward.fill"
        case .repeatMode:
            return "repeat"
        case .volume:
            return "speaker.wave.2.fill"
        case .favorite:
            return "heart"
        case .goBackward:
            return "gobackward.15"
        case .goForward:
            return "goforward.15"
        case .none:
            return ""
        }
    }

    var prefersLargeScale: Bool {
        self == .playPause
    }
}
