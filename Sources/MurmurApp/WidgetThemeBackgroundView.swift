import AppKit

final class WidgetThemeBackgroundView: NSView {
    private var theme = MurmurState.defaultValue.widget.theme
    private var backgroundImage: NSImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ theme: ThemeState) {
        self.theme = theme
        backgroundImage = theme.style.allowsCustomBackground
            ? theme.backgroundImagePath.flatMap { NSImage(contentsOfFile: $0) }
            : nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTheme(in: bounds)
    }

    private func drawTheme(in rect: CGRect) {
        switch theme.style {
        case .magazine:
            drawMagazine(in: rect)
        case .kraft:
            drawKraft(in: rect)
        case .polaroid:
            drawPolaroid(in: rect)
        case .collage:
            drawCollage(in: rect)
        case .corkboard:
            drawCorkboard(in: rect)
        }
    }

    private func drawMagazine(in rect: CGRect) {
        drawCustomBackground(in: rect, imageFraction: 0.30)
        NSColor(calibratedWhite: 0.96, alpha: backgroundImage == nil ? 0.94 : 0.74).setFill()
        rect.fill()
        NSColor(calibratedWhite: 0.34, alpha: 0.12).setStroke()
        let rule = NSBezierPath()
        rule.move(to: CGPoint(x: rect.minX + 30, y: rect.maxY - 62))
        rule.line(to: CGPoint(x: rect.maxX - 30, y: rect.maxY - 62))
        rule.lineWidth = 0.8
        rule.stroke()
    }

    private func drawKraft(in rect: CGRect) {
        NSColor(calibratedRed: 0.57, green: 0.47, blue: 0.34, alpha: 0.98).setFill()
        rect.fill()
        drawFibers(in: rect, color: NSColor(calibratedWhite: 0.08, alpha: 0.17), count: 92)
        drawFibers(in: rect, color: NSColor(calibratedRed: 0.94, green: 0.81, blue: 0.58, alpha: 0.12), count: 54)
        NSColor(calibratedWhite: 0.10, alpha: 0.18).setStroke()
        let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 12, dy: 12), xRadius: 18, yRadius: 18)
        edge.lineWidth = 14
        edge.stroke()
    }

    private func drawPolaroid(in rect: CGRect) {
        NSColor(calibratedRed: 0.56, green: 0.47, blue: 0.36, alpha: 0.78).setFill()
        rect.fill()
        drawFibers(in: rect, color: NSColor(calibratedRed: 0.16, green: 0.10, blue: 0.07, alpha: 0.18), count: 118)
        drawFibers(in: rect, color: NSColor(calibratedRed: 0.98, green: 0.87, blue: 0.66, alpha: 0.16), count: 76)

        let paper = polaroidPaperRect(in: rect)
        NSColor(calibratedWhite: 0.965, alpha: 0.99).setFill()
        NSBezierPath(roundedRect: paper, xRadius: 5, yRadius: 5).fill()
        drawFibers(in: paper, color: NSColor(calibratedWhite: 0.20, alpha: 0.035), count: 42)

        let photo = polaroidPhotoRect(in: rect)
        if let backgroundImage {
            drawImage(backgroundImage, aspectFillIn: photo, fraction: 0.96)
        } else {
            NSColor.black.setFill()
            NSBezierPath(rect: photo).fill()
        }

        NSColor(calibratedWhite: 0.08, alpha: 0.16).setStroke()
        let photoBorder = NSBezierPath(rect: photo)
        photoBorder.lineWidth = 1
        photoBorder.stroke()

        NSColor(calibratedWhite: 0.18, alpha: 0.14).setStroke()
        let border = NSBezierPath(roundedRect: paper, xRadius: 5, yRadius: 5)
        border.lineWidth = 1
        border.stroke()

        drawTape(in: CGRect(x: paper.midX - 44, y: paper.maxY - 12, width: 88, height: 18), color: NSColor(calibratedRed: 0.74, green: 0.60, blue: 0.40, alpha: 0.58))
        drawTape(in: CGRect(x: paper.maxX - 54, y: paper.minY + 22, width: 58, height: 15), color: NSColor(calibratedRed: 0.64, green: 0.52, blue: 0.36, alpha: 0.34))

        drawPressedFlower(at: CGPoint(x: paper.maxX - 38, y: paper.maxY - 40), scale: 0.82)
        drawPressedFlower(at: CGPoint(x: paper.minX + 58, y: paper.minY + 68), scale: 0.62)
        drawPressedFlower(at: CGPoint(x: paper.maxX - 26, y: paper.minY + 28), scale: 0.54)
        drawPressedLeaf(at: CGPoint(x: paper.minX + 38, y: paper.minY + 58), scale: 0.9)
        drawDriedSprig(from: CGPoint(x: rect.minX + 34, y: rect.minY + 156), height: 118)
    }

    private func drawCollage(in rect: CGRect) {
        drawCustomBackground(in: rect, imageFraction: 0.26)
        NSColor(calibratedRed: 0.94, green: 0.90, blue: 0.84, alpha: backgroundImage == nil ? 0.96 : 0.74).setFill()
        rect.fill()
        drawFibers(in: rect, color: NSColor(calibratedRed: 0.42, green: 0.35, blue: 0.30, alpha: 0.08), count: 48)

        let noteOne = CGRect(x: rect.minX + 20, y: rect.maxY - 112, width: 112, height: 58)
        let noteTwo = CGRect(x: rect.maxX - 150, y: rect.minY + 38, width: 114, height: 62)
        NSColor(calibratedRed: 0.96, green: 0.82, blue: 0.54, alpha: 0.36).setFill()
        NSBezierPath(roundedRect: noteOne, xRadius: 2, yRadius: 2).fill()
        NSColor(calibratedRed: 0.68, green: 0.78, blue: 0.72, alpha: 0.34).setFill()
        NSBezierPath(roundedRect: noteTwo, xRadius: 2, yRadius: 2).fill()
        drawTape(in: CGRect(x: rect.minX + 86, y: rect.maxY - 48, width: 70, height: 14), color: NSColor(calibratedRed: 0.84, green: 0.73, blue: 0.65, alpha: 0.54))
        drawTape(in: CGRect(x: rect.maxX - 128, y: rect.minY + 86, width: 58, height: 13), color: NSColor(calibratedRed: 0.67, green: 0.72, blue: 0.82, alpha: 0.48))
    }

    private func drawCorkboard(in rect: CGRect) {
        drawCustomBackground(in: rect, imageFraction: 0.24)
        NSColor(calibratedRed: 0.57, green: 0.38, blue: 0.22, alpha: backgroundImage == nil ? 0.97 : 0.72).setFill()
        rect.fill()
        drawCorkSpeckles(in: rect)
        NSColor(calibratedWhite: 0.08, alpha: 0.20).setStroke()
        let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 10, dy: 10), xRadius: 16, yRadius: 16)
        frame.lineWidth = 10
        frame.stroke()
    }

    private func drawCustomBackground(in rect: CGRect, imageFraction: CGFloat) {
        guard let backgroundImage else { return }
        guard backgroundImage.size.width > 0, backgroundImage.size.height > 0 else { return }
        drawImage(backgroundImage, aspectFillIn: rect, fraction: imageFraction)
    }

    private func drawImage(_ image: NSImage, aspectFillIn rect: CGRect, fraction: CGFloat) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let imageRect = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: fraction, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
    }

    private func polaroidPaperRect(in rect: CGRect) -> CGRect {
        rect.insetBy(dx: 28, dy: 20)
    }

    private func polaroidPhotoRect(in rect: CGRect) -> CGRect {
        let paper = polaroidPaperRect(in: rect)
        let side: CGFloat = 30
        let top: CGFloat = 32
        let bottom: CGFloat = 120
        return CGRect(
            x: paper.minX + side,
            y: paper.minY + bottom,
            width: paper.width - side * 2,
            height: max(80, paper.height - top - bottom)
        )
    }

    private func drawFibers(in rect: CGRect, color: NSColor, count: Int) {
        color.setStroke()
        for index in 0..<count {
            let x = rect.minX + rect.width * CGFloat((index * 37) % 101) / 100
            let y = rect.minY + rect.height * CGFloat((index * 17) % 101) / 100
            let length = CGFloat(14 + (index * 11) % 62)
            let line = NSBezierPath()
            line.move(to: CGPoint(x: x, y: y))
            line.line(to: CGPoint(x: min(rect.maxX - 16, x + length), y: y + CGFloat((index % 5) - 2)))
            line.lineWidth = 0.45
            line.stroke()
        }
    }

    private func drawCorkSpeckles(in rect: CGRect) {
        for index in 0..<176 {
            let x = rect.minX + rect.width * CGFloat((index * 29) % 101) / 100
            let y = rect.minY + rect.height * CGFloat((index * 43) % 101) / 100
            let size = CGFloat(1 + index % 3)
            let color = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.27, green: 0.15, blue: 0.08, alpha: 0.20)
                : NSColor(calibratedRed: 0.88, green: 0.68, blue: 0.42, alpha: 0.16)
            color.setFill()
            NSBezierPath(ovalIn: CGRect(x: x, y: y, width: size, height: size)).fill()
        }
    }

    private func drawTape(in rect: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
    }

    private func drawPaperScrap(in rect: CGRect, text: String) {
        NSColor(calibratedRed: 0.78, green: 0.69, blue: 0.55, alpha: 0.45).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        path.fill()
        drawFibers(in: rect, color: NSColor(calibratedWhite: 0.12, alpha: 0.12), count: 18)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Georgia", size: 12) ?? .systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 0.42),
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect.insetBy(dx: 8, dy: 8), withAttributes: attributes)
    }

    private func drawDriedSprig(from origin: CGPoint, height: CGFloat) {
        NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.10, alpha: 0.32).setStroke()
        let stem = NSBezierPath()
        stem.move(to: origin)
        stem.curve(to: CGPoint(x: origin.x + 20, y: origin.y + height), controlPoint1: CGPoint(x: origin.x - 4, y: origin.y + 36), controlPoint2: CGPoint(x: origin.x + 28, y: origin.y + 74))
        stem.lineWidth = 1
        stem.stroke()

        NSColor(calibratedRed: 0.86, green: 0.78, blue: 0.65, alpha: 0.42).setFill()
        for index in 0..<7 {
            let y = origin.y + CGFloat(index) * 15 + 18
            let x = origin.x + CGFloat(index % 3) * 7 + 4
            NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 5, height: 7)).fill()
            NSBezierPath(ovalIn: CGRect(x: x + 11, y: y + 4, width: 5, height: 7)).fill()
        }
    }

    private func drawPressedFlower(at center: CGPoint, scale: CGFloat) {
        let petalColor = NSColor(calibratedRed: 0.82, green: 0.70, blue: 0.64, alpha: 0.78)
        petalColor.setFill()
        for index in 0..<5 {
            let angle = CGFloat(index) * .pi * 2 / 5
            let x = center.x + cos(angle) * 8 * scale
            let y = center.y + sin(angle) * 8 * scale
            NSBezierPath(ovalIn: CGRect(x: x - 6 * scale, y: y - 8 * scale, width: 12 * scale, height: 16 * scale)).fill()
        }
        NSColor(calibratedRed: 0.55, green: 0.39, blue: 0.24, alpha: 0.72).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 4 * scale, y: center.y - 4 * scale, width: 8 * scale, height: 8 * scale)).fill()
    }

    private func drawPressedLeaf(at center: CGPoint, scale: CGFloat) {
        NSColor(calibratedRed: 0.59, green: 0.45, blue: 0.30, alpha: 0.58).setFill()
        let leaf = NSBezierPath()
        leaf.move(to: CGPoint(x: center.x, y: center.y + 20 * scale))
        leaf.curve(to: CGPoint(x: center.x, y: center.y - 18 * scale), controlPoint1: CGPoint(x: center.x - 22 * scale, y: center.y + 8 * scale), controlPoint2: CGPoint(x: center.x - 16 * scale, y: center.y - 12 * scale))
        leaf.curve(to: CGPoint(x: center.x, y: center.y + 20 * scale), controlPoint1: CGPoint(x: center.x + 16 * scale, y: center.y - 12 * scale), controlPoint2: CGPoint(x: center.x + 22 * scale, y: center.y + 8 * scale))
        leaf.fill()
    }
}
