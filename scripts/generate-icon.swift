#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift OUTPUT.png\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

image.lockFocus()

let background = NSBezierPath(
    roundedRect: NSRect(x: 44, y: 44, width: 936, height: 936),
    xRadius: 220,
    yRadius: 220
)
let gradient = NSGradient(colors: [
    NSColor(red: 0.12, green: 0.18, blue: 0.31, alpha: 1),
    NSColor(red: 0.36, green: 0.20, blue: 0.16, alpha: 1)
])!
gradient.draw(in: background, angle: -45)

let warmWhite = NSColor(red: 1.0, green: 0.94, blue: 0.80, alpha: 1)

let handle = NSBezierPath(ovalIn: NSRect(x: 585, y: 330, width: 235, height: 235))
handle.lineWidth = 68
warmWhite.setStroke()
handle.stroke()

let cup = NSBezierPath(
    roundedRect: NSRect(x: 230, y: 285, width: 470, height: 330),
    xRadius: 105,
    yRadius: 105
)
warmWhite.setFill()
cup.fill()

NSColor(red: 0.22, green: 0.14, blue: 0.13, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 250, y: 535, width: 430, height: 95)).fill()

let saucer = NSBezierPath()
saucer.move(to: NSPoint(x: 210, y: 260))
saucer.curve(
    to: NSPoint(x: 730, y: 260),
    controlPoint1: NSPoint(x: 300, y: 175),
    controlPoint2: NSPoint(x: 640, y: 175)
)
saucer.lineWidth = 48
saucer.lineCapStyle = .round
warmWhite.setStroke()
saucer.stroke()

for x in [350.0, 500.0, 650.0] {
    let steam = NSBezierPath()
    steam.move(to: NSPoint(x: x, y: 690))
    steam.curve(
        to: NSPoint(x: x, y: 870),
        controlPoint1: NSPoint(x: x - 70, y: 750),
        controlPoint2: NSPoint(x: x + 70, y: 810)
    )
    steam.lineWidth = 36
    steam.lineCapStyle = .round
    warmWhite.withAlphaComponent(0.88).setStroke()
    steam.stroke()
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Could not render icon\n".utf8))
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
