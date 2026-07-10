import AppKit

final class PetView: NSView {
    private var pet: PetState = MurmurState.defaultValue.pet
    private var image: NSImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ pet: PetState) {
        self.pet = pet
        if pet.kind == .customImage, let path = pet.imagePath {
            image = NSImage(contentsOfFile: path) ?? Self.builtInImage(for: pet.pose)
        } else {
            image = Self.builtInImage(for: pet.pose)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let image {
            image.draw(
                in: aspectFitRect(for: image, in: bounds),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return
        }

        let bodyRect = bounds.insetBy(dx: 10, dy: 12)
        NSColor(calibratedRed: 0.95, green: 0.91, blue: 0.84, alpha: 1).setFill()
        NSBezierPath(roundedRect: bodyRect, xRadius: 22, yRadius: 22).fill()

        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        NSBezierPath(ovalIn: CGRect(x: bodyRect.minX + 20, y: bodyRect.midY + 3, width: 6, height: 6)).fill()
        NSBezierPath(ovalIn: CGRect(x: bodyRect.maxX - 26, y: bodyRect.midY + 3, width: 6, height: 6)).fill()

        let mouth = NSBezierPath()
        mouth.move(to: CGPoint(x: bodyRect.midX - 6, y: bodyRect.midY - 8))
        mouth.curve(to: CGPoint(x: bodyRect.midX + 6, y: bodyRect.midY - 8), controlPoint1: CGPoint(x: bodyRect.midX - 2, y: bodyRect.midY - 13), controlPoint2: CGPoint(x: bodyRect.midX + 2, y: bodyRect.midY - 13))
        mouth.lineWidth = 1.6
        NSColor(calibratedWhite: 0.22, alpha: 0.85).setStroke()
        mouth.stroke()
    }

    private func aspectFitRect(for image: NSImage, in rect: CGRect) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else { return rect }

        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func builtInImage(for pose: PetPose) -> NSImage? {
        if let url = Bundle.main.url(forResource: pose.resourceName, withExtension: "png", subdirectory: "Pets/cat") {
            return NSImage(contentsOf: url)
        }

        let localPath = "Resources/Pets/cat/\(pose.resourceName).png"
        return NSImage(contentsOfFile: localPath)
    }
}
