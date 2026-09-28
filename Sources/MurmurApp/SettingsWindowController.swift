import AppKit
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController {
    private var state: MurmurState
    private let onSave: @MainActor (MurmurState) -> Void

    private let phraseField = NSTextField()
    private let noteField = NSTextField()
    private let coverTextField = NSTextField()
    private let coverModePopup = NSPopUpButton()
    private let petModePopup = NSPopUpButton()
    private let petEdgePopup = NSPopUpButton()
    private let transparencySlider = NSSlider(value: 0.72, minValue: 0.35, maxValue: 0.95, target: nil, action: nil)
    private let blurSlider = NSSlider(value: 0.82, minValue: 0.2, maxValue: 1.0, target: nil, action: nil)
    private let radiusSlider = NSSlider(value: 26, minValue: 10, maxValue: 36, target: nil, action: nil)
    private let expandedCheckbox = NSButton(checkboxWithTitle: "展开完整组件", target: nil, action: nil)
    private let blurredCheckbox = NSButton(checkboxWithTitle: "默认显示模糊封面", target: nil, action: nil)
    private let taskStack = NSStackView()
    private var taskFields: [UUID: NSTextField] = [:]
    private var taskChecks: [UUID: NSButton] = [:]

    init(state: MurmurState, onSave: @escaping @MainActor (MurmurState) -> Void) {
        self.state = state
        self.onSave = onSave

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Murmur Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]

        super.init(window: window)
        window.contentView = makeContentView()
        populate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        let content = NSView()
        scrollView.documentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24)
        ])

        stack.addArrangedSubview(sectionTitle("内容"))
        stack.addArrangedSubview(row("主文案", phraseField))
        stack.addArrangedSubview(row("私密碎碎念", noteField))

        stack.addArrangedSubview(sectionTitle("模糊封面"))
        coverModePopup.addItems(withTitles: ["文字封面", "图片/表情包封面"])
        stack.addArrangedSubview(row("封面类型", coverModePopup))
        stack.addArrangedSubview(row("封面文案", coverTextField))
        stack.addArrangedSubview(buttonRow([
            NSButton(title: "选择封面图片...", target: self, action: #selector(chooseCoverImage)),
            NSButton(title: "清除封面图片", target: self, action: #selector(clearCoverImage))
        ]))

        stack.addArrangedSubview(sectionTitle("桌宠"))
        petModePopup.addItems(withTitles: ["内置桌宠", "自定义图片"])
        stack.addArrangedSubview(row("桌宠类型", petModePopup))
        petEdgePopup.addItems(withTitles: ["右上角", "左上角", "右下角"])
        stack.addArrangedSubview(row("展开位置", petEdgePopup))
        stack.addArrangedSubview(buttonRow([
            NSButton(title: "选择桌宠图片...", target: self, action: #selector(choosePetImage)),
            NSButton(title: "恢复内置桌宠", target: self, action: #selector(resetBuiltInPet))
        ]))

        stack.addArrangedSubview(sectionTitle("状态与视觉"))
        stack.addArrangedSubview(expandedCheckbox)
        stack.addArrangedSubview(blurredCheckbox)
        stack.addArrangedSubview(row("透明度", transparencySlider))
        stack.addArrangedSubview(row("模糊强度", blurSlider))
        stack.addArrangedSubview(row("圆角", radiusSlider))

        stack.addArrangedSubview(sectionTitle("待办列表"))
        taskStack.orientation = .vertical
        taskStack.alignment = .leading
        taskStack.spacing = 8
        taskStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(taskStack)
        stack.addArrangedSubview(buttonRow([
            NSButton(title: "新增任务", target: self, action: #selector(addTask)),
            NSButton(title: "删除已完成任务", target: self, action: #selector(deleteCompletedTasks))
        ]))

        stack.addArrangedSubview(sectionTitle("操作"))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let saveCloseButton = NSButton(title: "保存并关闭", target: self, action: #selector(saveAndClose))
        let quitButton = NSButton(title: "退出 Murmur", target: self, action: #selector(quitMurmur))
        quitButton.bezelStyle = .rounded
        stack.addArrangedSubview(buttonRow([saveButton, saveCloseButton, quitButton]))

        return root
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func row(_ label: String, _ control: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12, weight: .medium)
        labelView.textColor = .secondaryLabelColor
        labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 360).isActive = true

        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(control)
        return stack
    }

    private func buttonRow(_ buttons: [NSButton]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for button in buttons {
            button.bezelStyle = .rounded
            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func populate() {
        phraseField.stringValue = state.content.mainPhrase
        noteField.stringValue = state.content.privateNote
        coverTextField.stringValue = state.cover.text
        coverModePopup.selectItem(at: state.cover.mode == .text ? 0 : 1)
        petModePopup.selectItem(at: state.pet.kind == .builtIn ? 0 : 1)
        petEdgePopup.selectItem(at: PetEdge.allCases.firstIndex(of: state.pet.edge) ?? 0)
        transparencySlider.doubleValue = state.widget.theme.transparency
        blurSlider.doubleValue = state.widget.theme.blurStrength
        radiusSlider.doubleValue = state.widget.theme.cornerRadius
        expandedCheckbox.state = state.widget.isExpanded ? .on : .off
        blurredCheckbox.state = state.widget.isBlurred ? .on : .off
        rebuildTaskRows()
    }

    private func rebuildTaskRows() {
        taskStack.arrangedSubviews.forEach { view in
            taskStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        taskFields.removeAll()
        taskChecks.removeAll()

        if state.content.tasks.isEmpty {
            let empty = NSTextField(labelWithString: "还没有任务。点击“新增任务”开始。")
            empty.textColor = .secondaryLabelColor
            taskStack.addArrangedSubview(empty)
            return
        }

        for task in state.content.tasks {
            taskStack.addArrangedSubview(taskRow(task))
        }
    }

    private func taskRow(_ task: TaskItem) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = task.completed ? .on : .off
        checkbox.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let field = NSTextField(string: task.text)
        field.widthAnchor.constraint(equalToConstant: 360).isActive = true

        let deleteButton = NSButton(title: "删除", target: self, action: #selector(deleteTask(_:)))
        deleteButton.identifier = NSUserInterfaceItemIdentifier(task.id.uuidString)
        deleteButton.bezelStyle = .rounded

        taskChecks[task.id] = checkbox
        taskFields[task.id] = field

        stack.addArrangedSubview(checkbox)
        stack.addArrangedSubview(field)
        stack.addArrangedSubview(deleteButton)
        return stack
    }

    @objc private func chooseCoverImage() {
        guard let path = chooseImagePath() else { return }
        state.cover.mode = .image
        state.cover.imagePath = path
        coverModePopup.selectItem(at: 1)
    }

    @objc private func clearCoverImage() {
        state.cover.imagePath = nil
        state.cover.mode = .text
        coverModePopup.selectItem(at: 0)
    }

    @objc private func choosePetImage() {
        guard let path = chooseImagePath() else { return }
        let sourceURL = URL(fileURLWithPath: path)
        Task { [weak self] in
            guard let self else { return }
            guard let importedPath = await PetImageImporter.importImage(
                from: sourceURL,
                presenting: window
            ) else { return }

            state.pet.kind = .customImage
            state.pet.imagePath = importedPath
            petModePopup.selectItem(at: 1)
        }
    }

    @objc private func resetBuiltInPet() {
        state.pet.kind = .builtIn
        state.pet.imagePath = nil
        petModePopup.selectItem(at: 0)
    }

    @objc private func addTask() {
        collectForm()
        state.content.tasks.append(TaskItem(text: "New task"))
        rebuildTaskRows()
    }

    @objc private func deleteTask(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue, let id = UUID(uuidString: rawValue) else { return }
        collectForm()
        state.content.tasks.removeAll { $0.id == id }
        rebuildTaskRows()
    }

    @objc private func deleteCompletedTasks() {
        collectForm()
        state.content.tasks.removeAll { $0.completed }
        rebuildTaskRows()
    }

    @objc private func save() {
        collectForm()
        onSave(state)
    }

    @objc private func saveAndClose() {
        save()
        close()
    }

    @objc private func quitMurmur() {
        collectForm()
        onSave(state)
        NSApp.terminate(nil)
    }

    private func collectForm() {
        state.content.mainPhrase = phraseField.stringValue
        state.content.privateNote = noteField.stringValue
        state.cover.text = coverTextField.stringValue
        state.cover.mode = coverModePopup.indexOfSelectedItem == 0 ? .text : .image
        state.pet.kind = petModePopup.indexOfSelectedItem == 0 ? .builtIn : .customImage
        state.pet.edge = PetEdge.allCases[petEdgePopup.indexOfSelectedItem]
        state.widget.theme.transparency = transparencySlider.doubleValue
        state.widget.theme.blurStrength = blurSlider.doubleValue
        state.widget.theme.cornerRadius = radiusSlider.doubleValue
        state.widget.isExpanded = expandedCheckbox.state == .on
        state.widget.isBlurred = blurredCheckbox.state == .on

        for index in state.content.tasks.indices {
            let id = state.content.tasks[index].id
            state.content.tasks[index].text = taskFields[id]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? state.content.tasks[index].text
            state.content.tasks[index].completed = taskChecks[id]?.state == .on
            state.content.tasks[index].updatedAt = Date()
        }

        state.content.tasks.removeAll { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func chooseImagePath() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
