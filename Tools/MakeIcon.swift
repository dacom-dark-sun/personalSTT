#!/usr/bin/env swift
// Renders the personal-stt icon as an .iconset directory.
// Output: <out-dir>/icon_{size}[@2x].png at all sizes macOS needs.
// Usage: swift Tools/MakeIcon.swift <output.iconset>
//
// The icon is drawn procedurally — no external assets. Design:
//   flat dark-charcoal squircle + centered white SF Symbols microphone.

import AppKit
import Foundation

_ = NSApplication.shared

let outDir = CommandLine.arguments.dropFirst().first ?? "icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("16x16", 16),   ("16x16@2x", 32),
    ("32x32", 32),   ("32x32@2x", 64),
    ("128x128", 128),("128x128@2x", 256),
    ("256x256", 256),("256x256@2x", 512),
    ("512x512", 512),("512x512@2x", 1024),
]

func drawIcon(size: CGFloat) {
    // Squircle background — iOS/macOS icon corner radius convention (~22.37%).
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).setFill()
    bg.fill()

    // Microphone glyph — SF Symbols, tinted white via sourceAtop compositing.
    guard let symbol = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) else {
        fputs("warning: SF Symbols unavailable; icon will be blank squircle\n", stderr)
        return
    }
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.56, weight: .regular)
    let glyph = symbol.withSymbolConfiguration(cfg) ?? symbol
    let gs = glyph.size
    let gr = NSRect(
        x: (size - gs.width) / 2,
        y: (size - gs.height) / 2,
        width: gs.width,
        height: gs.height
    )
    glyph.draw(in: gr)
    NSColor.white.set()
    gr.fill(using: .sourceAtop)
}

func renderPNG(size: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("NSBitmapImageRep init failed") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed")
    }
    return data
}

for (name, px) in sizes {
    let data = renderPNG(size: px)
    let path = "\(outDir)/icon_\(name).png"
    try data.write(to: URL(fileURLWithPath: path))
    print("✔ \(path) (\(px)×\(px))")
}
