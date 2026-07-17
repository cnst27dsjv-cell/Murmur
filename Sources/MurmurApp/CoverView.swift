import AppKit

final class CoverView: NSView {
    private let backgroundView = WidgetThemeBackgroundView()
    private let coverContent = NSVisualEffectView()
    private let imageView = NSImageView()
    private let textLabel = NSTextField(labelWithString: "")
    private var cover = MurmurState.defaultValue.cover
    private var theme = MurmurState.defaultValue.widget.theme

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        coverContent.material = .underWindowBackground
        coverContent.blendingMode = .withinWindow
        coverContent.state = .active
        coverContent.wantsLayer = true
        coverContent.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true

        textLabel.alignment = .center
        textLabel.maximumNumberOfLines = 4
        textLabel.lineBreakMode = .byWordWrapping

        addSubview(backgroundView)
        addSubview(coverContent)
        addSubview(imageView)
        addSubview(textLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        coverContent.frame = bounds

        let sideInset: CGFloat = theme.style == .polaroid ? 48 : 38
        let contentRect = bounds.insetBy(dx: sideInset, dy: 48)

        switch cover.mode {
        case .text:
            textLabel.frame = contentRect
            imageView.frame = .zero
        case .image:
            let maxHeight = contentRect.height - (cover.text.isEmpty ? 0 : 44)
            let imageRect = centeredImageRect(in: CGRect(x: contentRect.minX, y: contentRect.minY + (cover.text.isEmpty ? 0 : 34), width: contentRect.width, height: maxHeight))
            imageView.frame = imageRect
            textLabel.frame = CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: cover.text.isEmpty ? 0 : 30)
        }

        let radius: CGFloat = theme.style == .polaroid ? 2 : (theme.style == .magazine ? 12 : 5)
        imageView.layer?.cornerRadius = radius
    }

    func apply(cover: CoverState, theme: ThemeState) {
        self.cover = cover
        self.theme = theme
        backgroundView.apply(theme)

        switch cover.mode {
        case .text:
            imageView.isHidden = true
            textLabel.isHidden = false
            textLabel.stringValue = cover.text.isEmpty ? "soft focus" : cover.text
        case .image:
            if let path = cover.imagePath, let image = NSImage(contentsOfFile: path) {
                imageView.image = image
                imageView.isHidden = false
                textLabel.isHidden = cover.text.isEmpty
                textLabel.stringValue = cover.text
            } else {
                imageView.image = nil
                imageView.isHidden = true
                textLabel.isHidden = false
                textLabel.stringValue = cover.text.isEmpty ? "soft focus" : cover.text
            }
        }

        applyTypography()
        needsLayout = true
    }

    private func centeredImageRect(in rect: CGRect) -> CGRect {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return rect }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func applyTypography() {
        switch theme.style {
        case .magazine:
            textLabel.font = NSFont(name: "Baskerville-SemiBold", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
            textLabel.textColor = NSColor.labelColor.withAlphaComponent(0.92)
        case .kraft:
            textLabel.font = NSFont(name: "Courier", size: 25) ?? .monospacedSystemFont(ofSize: 25, weight: .regular)
            textLabel.textColor = NSColor(calibratedWhite: 0.10, alpha: 0.88)
        case .polaroid:
            textLabel.font = NSFont(name: "Noteworthy-Light", size: 23) ?? .systemFont(ofSize: 23, weight: .medium)
            textLabel.textColor = NSColor(calibratedWhite: 0.18, alpha: 0.90)
        case .collage:
            textLabel.font = NSFont(name: "Noteworthy-Bold", size: 25) ?? .systemFont(ofSize: 25, weight: .semibold)
            textLabel.textColor = NSColor(calibratedRed: 0.20, green: 0.17, blue: 0.15, alpha: 0.88)
        case .corkboard:
            textLabel.font = NSFont(name: "AvenirNext-DemiBold", size: 27) ?? .systemFont(ofSize: 27, weight: .semibold)
            textLabel.textColor = NSColor.white.withAlphaComponent(0.94)
        }
    }
}
