import AppKit

final class CoverView: NSView {
    private let imageView = NSImageView()
    private let textLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let imageWidth = min(bounds.width * 0.76, bounds.width - 54)
        let imageHeight = min(bounds.height * 0.58, bounds.height - 72)
        imageView.frame = CGRect(
            x: (bounds.width - imageWidth) / 2,
            y: (bounds.height - imageHeight) / 2,
            width: imageWidth,
            height: imageHeight
        )
        let textHeight = min(bounds.height - 72, 84)
        textLabel.frame = CGRect(
            x: 34,
            y: (bounds.height - textHeight) / 2 - 2,
            width: bounds.width - 68,
            height: textHeight
        )
    }

    func apply(_ cover: CoverState) {
        switch cover.mode {
        case .text:
            imageView.isHidden = true
            textLabel.isHidden = false
            textLabel.stringValue = cover.text.isEmpty ? "soft focus" : cover.text
        case .image:
            if let path = cover.imagePath, let image = NSImage(contentsOfFile: path) {
                imageView.image = image
                imageView.isHidden = false
                textLabel.isHidden = true
            } else {
                imageView.isHidden = true
                textLabel.isHidden = false
                textLabel.stringValue = cover.text.isEmpty ? "soft focus" : cover.text
            }
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor
        layer?.masksToBounds = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 18
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        textLabel.alignment = .center
        textLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        textLabel.textColor = NSColor.labelColor.withAlphaComponent(0.92)
        textLabel.maximumNumberOfLines = 2
        textLabel.lineBreakMode = .byWordWrapping
        addSubview(textLabel)
    }
}
