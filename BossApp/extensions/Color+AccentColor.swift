//
//  Color+AccentColor.swift
//  Boss App
//
//

import SwiftUI

extension Color {
    static var effectiveAccent: Color {
        return .accentColor
    }
    
    /// Returns a darker version of the accent color suitable for backgrounds
    static var effectiveAccentBackground: Color {
        return Color.effectiveAccent.opacity(0.25)
    }
}

extension NSColor {
    static var effectiveAccent: NSColor {
        return NSColor.controlAccentColor
    }
    
    /// Returns a darker version of the accent color as NSColor suitable for backgrounds
    static var effectiveAccentBackground: NSColor {
        return NSColor.controlAccentColor.withAlphaComponent(0.25)
    }
}
