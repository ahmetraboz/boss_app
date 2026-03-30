//
//  SwiftUI+MoveToOverlay.swift
//  BossWindowBridge
//
//

import Foundation
import SwiftUI

public extension View {
    func moveToSky() -> some View {
        modifier(MoveToOverlayModifier())
    }
}

struct MoveToOverlayModifier: ViewModifier {
    @State var window: NSWindow? = nil
    @State var hasMoved = false

    func body(content: Content) -> some View {
        content
            .background(WindowReadingView($window))
            .onChange(of: window) { _ in
                guard !hasMoved, let window else { return }
                hasMoved = true
                WindowBridgeOperator.shared.delegateWindow(window)
            }
    }
}
