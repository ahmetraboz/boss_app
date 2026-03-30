//
//  generic.swift
//  Boss App
//
//

import Foundation
import BossConfig

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState {
    case closed
    case open
}

public enum NotchViews {
    case home
    case shelf
    case clipboard
    case screenshots
    case notes
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

enum DownloadIndicatorStyle: String, BossConfig.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, BossConfig.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, BossConfig.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, BossConfig.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, BossConfig.Serializable {
    case white = "Beyaz"
    case albumArt = "Albüm kapağıyla eşleştir"
    case accent = "Vurgu rengi"
}
