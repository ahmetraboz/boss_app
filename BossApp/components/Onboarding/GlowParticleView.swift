//
//  GlowParticleView.swift
//  Boss App
//
//

import SwiftUI
import AppKit

final class GlowParticleCanvas: NSView {
    private var emitterLayer: CAEmitterLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureEmitter()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureEmitter() {
        let layer = CAEmitterLayer()
        layer.emitterShape = .rectangle
        layer.emitterMode = .surface
        layer.renderMode = .oldestFirst

        let cell = CAEmitterCell()
        cell.contents = NSImage(named: "glowdot")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        cell.birthRate = 28
        cell.lifetime = 4.5
        cell.velocity = 12
        cell.velocityRange = 7
        cell.emissionRange = .pi * 2
        cell.scale = 0.16
        cell.scaleRange = 0.08
        cell.alphaSpeed = -0.45
        cell.yAcceleration = 6

        layer.emitterCells = [cell]
        self.layer?.addSublayer(layer)
        emitterLayer = layer
        refreshEmitterGeometry()
    }

    private func refreshEmitterGeometry() {
        guard let emitterLayer else {
            return
        }

        emitterLayer.frame = bounds
        emitterLayer.emitterSize = bounds.size
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        let dynamicBirthRate = max(12, Float((bounds.width * bounds.height) / 5000))
        emitterLayer.emitterCells?.first?.birthRate = dynamicBirthRate
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshEmitterGeometry()
    }
}

struct GlowParticleView: NSViewRepresentable {
    func makeNSView(context: Context) -> GlowParticleCanvas {
        GlowParticleCanvas()
    }

    func updateNSView(_ nsView: GlowParticleCanvas, context: Context) {}
}
