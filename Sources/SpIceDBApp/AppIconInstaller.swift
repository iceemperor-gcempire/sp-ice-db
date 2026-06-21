import AppKit

@MainActor
enum AppIconInstaller {
    static func install() {
        NSApplication.shared.applicationIconImage = makeIcon()
    }

    private static func makeIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let backgroundPath = NSBezierPath(
            roundedRect: rect.insetBy(dx: 32, dy: 32),
            xRadius: 96,
            yRadius: 96
        )
        backgroundPath.addClip()

        NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.35, blue: 0.58, alpha: 1),
            NSColor(calibratedRed: 0.14, green: 0.63, blue: 0.66, alpha: 1),
            NSColor(calibratedRed: 0.92, green: 0.97, blue: 1, alpha: 1)
        ])?.draw(in: rect, angle: 135)

        NSColor.white.withAlphaComponent(0.22).setStroke()
        backgroundPath.lineWidth = 12
        backgroundPath.stroke()

        drawDatabaseMark(in: rect)
        drawInitials(in: rect)

        return image
    }

    private static func drawDatabaseMark(in rect: NSRect) {
        let markRect = NSRect(x: 126, y: 104, width: 260, height: 92)
        let strokeColor = NSColor.white.withAlphaComponent(0.82)
        strokeColor.setStroke()

        for offset in stride(from: 0, through: 48, by: 24) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: markRect.minX, y: markRect.minY + CGFloat(offset)))
            path.curve(
                to: NSPoint(x: markRect.maxX, y: markRect.minY + CGFloat(offset)),
                controlPoint1: NSPoint(x: markRect.minX + 72, y: markRect.minY + CGFloat(offset) - 26),
                controlPoint2: NSPoint(x: markRect.maxX - 72, y: markRect.minY + CGFloat(offset) - 26)
            )
            path.lineWidth = 10
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private static func drawInitials(in rect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 170, weight: .black),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
            .kern: 4
        ]

        NSString(string: "SP").draw(
            in: NSRect(x: rect.minX, y: 220, width: rect.width, height: 190),
            withAttributes: attributes
        )
    }
}
