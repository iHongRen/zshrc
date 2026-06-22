import AppKit

private extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func strokeRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

private func fillGradient(_ rect: NSRect, colors: [NSColor], angle: CGFloat, radius: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGradient(colors: colors)?.draw(in: path, angle: angle)
}

private func drawText(
    _ string: String,
    in rect: NSRect,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]

    let attributed = NSAttributedString(string: string, attributes: attributes)
    let size = attributed.size()
    let drawRect = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    attributed.draw(in: drawRect)
}

private func drawGlow(center: NSPoint, radius: CGFloat, color: NSColor) {
    let gradient = NSGradient(colors: [
        color,
        color.withAlphaComponent(0)
    ])

    gradient?.draw(
        fromCenter: center,
        radius: 0,
        toCenter: center,
        radius: radius,
        options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
    )
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to allocate bitmap")
}

NSGraphicsContext.saveGraphicsState()
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create graphics context")
}

NSGraphicsContext.current = graphicsContext
graphicsContext.cgContext.setAllowsAntialiasing(true)
graphicsContext.cgContext.setShouldAntialias(true)

let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let iconRect = canvas.insetBy(dx: 78, dy: 78)
let cornerRadius: CGFloat = 220

fillGradient(
    iconRect,
    colors: [
        NSColor(hex: 0x4B92F4),
        NSColor(hex: 0x2F81F7),
        NSColor(hex: 0x0EA5E9)
    ],
    angle: 315,
    radius: cornerRadius
)

drawGlow(
    center: NSPoint(x: iconRect.minX + 220, y: iconRect.maxY - 180),
    radius: 260,
    color: NSColor.white.withAlphaComponent(0.15)
)

drawGlow(
    center: NSPoint(x: iconRect.maxX - 150, y: iconRect.minY + 140),
    radius: 220,
    color: NSColor(hex: 0xFFFFFF, alpha: 0.08)
)

strokeRoundedRect(
    iconRect.insetBy(dx: 2, dy: 2),
    radius: cornerRadius - 2,
    color: NSColor.white.withAlphaComponent(0.16),
    width: 2
)

let symbolRect = NSRect(
    x: iconRect.minX + 180,
    y: iconRect.minY + 150,
    width: iconRect.width - 360,
    height: iconRect.height - 300
)

drawText(
    "~",
    in: symbolRect.offsetBy(dx: 0, dy: 16),
    fontSize: 720,
    weight: .bold,
    color: .white
)

let outputURL = URL(fileURLWithPath: "/Users/cxy/Desktop/CXY/zshrc/Designs/zshrc-app-icon-1024.png")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}

try pngData.write(to: outputURL)
NSGraphicsContext.restoreGraphicsState()

print(outputURL.path)
