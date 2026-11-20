#!/usr/bin/env swift
//
// Draws Profile Picker's artwork: a menu card listing several browsers, with a pointer.
// Run from the repository root:  xcrun swift scripts/make-icon.swift
// Output goes to ProfilePicker/Assets.xcassets and AppStore/AppIcon-1024.png.
//
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("ProfilePicker/Assets.xcassets")
let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
let statusSet = assets.appendingPathComponent("StatusIcon.imageset")
let accentSet = assets.appendingPathComponent("AccentColor.colorset")
let storeDir = root.appendingPathComponent("AppStore")

let colorSpace = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: colorSpace,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ]
    )!
}

func makeContext(size: Int) -> CGContext {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    // Draw in top-left coordinates so the design reads the same way as the artwork.
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    return context
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
}

/// Rounded square in the macOS icon grid, with a menu card and a pointer.
func drawAppIcon(_ context: CGContext, size: CGFloat) {
    let margin = size * 0.098
    let body = size - margin * 2
    let bodyRect = CGRect(x: margin, y: margin, width: body, height: body)
    let shape = CGPath(
        roundedRect: bodyRect, cornerWidth: body * 0.225, cornerHeight: body * 0.225, transform: nil
    )

    context.saveGState()
    context.addPath(shape)
    context.clip()

    // Indigo to violet, lit from the top-left.
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [rgb(0x5A8CFF), rgb(0x5B34E8)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.minY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [rgb(0xFFFFFF, 0.34), rgb(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    let glowCenter = CGPoint(x: bodyRect.minX + body * 0.24, y: bodyRect.minY + body * 0.10)
    context.drawRadialGradient(
        glow,
        startCenter: glowCenter, startRadius: 0,
        endCenter: glowCenter, endRadius: body * 0.62,
        options: []
    )

    // Slight darkening at the bottom gives the tile depth.
    let vignette = CGGradient(
        colorsSpace: colorSpace,
        colors: [rgb(0x1B0B66, 0), rgb(0x1B0B66, 0.28)] as CFArray,
        locations: [0.55, 1]
    )!
    context.drawLinearGradient(
        vignette,
        start: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
        end: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
        options: []
    )
    context.restoreGState()

    // Menu card.
    let cardRect = CGRect(
        x: bodyRect.minX + body * 0.225,
        y: bodyRect.minY + body * 0.195,
        width: body * 0.55,
        height: body * 0.445
    )
    let card = CGPath(
        roundedRect: cardRect, cornerWidth: body * 0.06, cornerHeight: body * 0.06, transform: nil
    )
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: body * 0.018), blur: body * 0.055, color: rgb(0x140A45, 0.34))
    context.setFillColor(rgb(0xFFFFFF, 0.97))
    context.addPath(card)
    context.fillPath()
    context.restoreGState()

    // Three browser rows: a colored dot and a label bar.
    let padding = cardRect.width * 0.09
    let rowHeight = cardRect.height / 3
    let dot = body * 0.061
    let rowColors: [UInt32] = [0x2F7CF6, 0xF2994A, 0x27AE60]

    for (index, hex) in rowColors.enumerated() {
        let centerY = cardRect.minY + rowHeight * (CGFloat(index) + 0.5)
        let dotRect = CGRect(
            x: cardRect.minX + padding,
            y: centerY - dot / 2,
            width: dot,
            height: dot
        )
        context.setFillColor(rgb(hex))
        context.fillEllipse(in: dotRect)

        // A soft highlight makes the dots read as browser icons rather than plain bullets.
        context.setFillColor(rgb(0xFFFFFF, 0.30))
        context.fillEllipse(in: dotRect.insetBy(dx: dot * 0.22, dy: dot * 0.22).offsetBy(dx: -dot * 0.10, dy: -dot * 0.10))

        let barX = dotRect.maxX + body * 0.027
        let bar = CGRect(
            x: barX,
            y: centerY - body * 0.011,
            width: cardRect.maxX - padding - barX,
            height: body * 0.022
        )
        context.setFillColor(rgb(0xC5C9D8))
        context.addPath(CGPath(roundedRect: bar, cornerWidth: bar.height / 2, cornerHeight: bar.height / 2, transform: nil))
        context.fillPath()
    }

    // Pointer, with its tip inside the card's bottom-right corner.
    let cursorScale = body * 0.19
    context.saveGState()
    context.translateBy(x: bodyRect.minX + body * 0.70, y: bodyRect.minY + body * 0.625)
    context.scaleBy(x: cursorScale, y: cursorScale)
    let pointer = CGMutablePath()
    pointer.move(to: CGPoint(x: 0, y: 0))
    pointer.addLine(to: CGPoint(x: 0, y: 0.86))
    pointer.addLine(to: CGPoint(x: 0.21, y: 0.66))
    pointer.addLine(to: CGPoint(x: 0.36, y: 0.97))
    pointer.addLine(to: CGPoint(x: 0.50, y: 0.90))
    pointer.addLine(to: CGPoint(x: 0.35, y: 0.60))
    pointer.addLine(to: CGPoint(x: 0.60, y: 0.60))
    pointer.closeSubpath()
    context.setShadow(offset: CGSize(width: 0, height: 0.03), blur: 0.06, color: rgb(0x140A45, 0.35))
    context.addPath(pointer)
    context.setFillColor(rgb(0xFFFFFF))
    context.setStrokeColor(rgb(0x1C1C2E))
    context.setLineWidth(0.06)
    context.setLineJoin(.round)
    context.drawPath(using: .fillStroke)
    context.restoreGState()
}

/// Monochrome menu glyph for the menu bar. Rendered as a template image.
func drawStatusIcon(_ context: CGContext, size: CGFloat) {
    let scale = size / 18
    context.scaleBy(x: scale, y: scale)

    context.setStrokeColor(rgb(0x000000))
    context.setFillColor(rgb(0x000000))
    context.setLineWidth(1.5)
    let card = CGRect(x: 1.5, y: 2.25, width: 15, height: 13.5)
    context.addPath(CGPath(roundedRect: card, cornerWidth: 3, cornerHeight: 3, transform: nil))
    context.strokePath()

    for row in 0..<3 {
        let centerY = 6.1 + CGFloat(row) * 2.9
        context.fillEllipse(in: CGRect(x: 4.2, y: centerY - 0.85, width: 1.7, height: 1.7))
        let bar = CGRect(x: 7.2, y: centerY - 0.7, width: 6.6, height: 1.4)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: 0.7, cornerHeight: 0.7, transform: nil))
        context.fillPath()
    }
}

func renderIcon(pixels: Int) -> CGImage {
    let context = makeContext(size: pixels)
    drawAppIcon(context, size: CGFloat(pixels))
    return context.makeImage()!
}

func renderStatus(pixels: Int) -> CGImage {
    let context = makeContext(size: pixels)
    drawStatusIcon(context, size: CGFloat(pixels))
    return context.makeImage()!
}

// MARK: - App icon set

try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: statusSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: accentSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

let macSizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

var appIconImages: [String] = []
for (points, scale) in macSizes {
    let pixels = points * scale
    let name = "icon_\(points)x\(points)\(scale > 1 ? "@\(scale)x" : "").png"
    write(renderIcon(pixels: pixels), to: iconSet.appendingPathComponent(name))
    appIconImages.append("""
        {
          "filename" : "\(name)",
          "idiom" : "mac",
          "scale" : "\(scale)x",
          "size" : "\(points)x\(points)"
        }
    """)
}

try """
{
  "images" : [
\(appIconImages.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Menu bar icon

for scale in 1...3 {
    let pixels = 18 * scale
    let suffix = scale == 1 ? "" : "@\(scale)x"
    let name = "StatusIcon\(suffix).png"
    write(renderStatus(pixels: pixels), to: statusSet.appendingPathComponent(name))
}

try """
{
  "images" : [
    { "filename" : "StatusIcon.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "StatusIcon@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "StatusIcon@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
""".write(to: statusSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Accent colour

try """
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.910", "green" : "0.420", "red" : "0.333" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "1.000", "green" : "0.545", "red" : "0.451" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".write(to: accentSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Root asset catalogue + App Store copy

try """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".write(to: assets.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

write(renderIcon(pixels: 1024), to: storeDir.appendingPathComponent("AppIcon-1024.png"))
print("Icons written to \(assets.path) and \(storeDir.path)")
