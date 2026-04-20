import AppKit

/// Clean, single-pane settings window. Values are committed on Done or on window close.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let config: Config
    private let onChange: () -> Void

    private var apiKeyField: NSSecureTextField!
    private var baseURLField: NSTextField!
    private var modelField: NSTextField!
    private var languageField: NSTextField!

    init(config: Config, onChange: @escaping () -> Void) {
        self.config = config
        self.onChange = onChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.level = .floating

        super.init(window: window)
        window.delegate = self
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        guard let window = window else { return }

        let content = NSView()

        let heading = NSTextField(labelWithString: "Settings")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        heading.textColor = .labelColor
        heading.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString:
            "Hold Right ⌥ to dictate · Right ⌘ + ⌥ to toggle"
        )
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        apiKeyField   = makeSecureField(current: config.apiKey,   placeholder: "sk-…")
        baseURLField  = makeField(      current: config.baseURL,  placeholder: "https://api.openai.com/v1")
        modelField    = makeField(      current: config.model,    placeholder: "whisper-1")
        languageField = makeField(      current: config.language, placeholder: "ru")

        let grid = NSGridView(views: [
            [makeLabel("API Key"),  apiKeyField],
            [makeLabel("Base URL"), baseURLField],
            [makeLabel("Model"),    modelField],
            [makeLabel("Language"), languageField],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 14
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        for i in 0..<grid.numberOfRows {
            grid.row(at: i).yPlacement = .center
        }

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(done))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        doneBtn.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(heading)
        content.addSubview(hint)
        content.addSubview(grid)
        content.addSubview(doneBtn)

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 40),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),

            hint.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            hint.leadingAnchor.constraint(equalTo: heading.leadingAnchor),

            grid.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),

            doneBtn.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 28),
            doneBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            doneBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            doneBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
        ])

        window.contentView = content
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        return label
    }

    private func makeField(current: String, placeholder: String) -> NSTextField {
        let f = NSTextField(string: current)
        f.placeholderString = placeholder
        f.font = .systemFont(ofSize: 13)
        f.isBezeled = true
        f.bezelStyle = .roundedBezel
        f.drawsBackground = true
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func makeSecureField(current: String, placeholder: String) -> NSSecureTextField {
        let f = NSSecureTextField(string: current)
        f.placeholderString = placeholder
        f.font = .systemFont(ofSize: 13)
        f.isBezeled = true
        f.bezelStyle = .roundedBezel
        f.drawsBackground = true
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    // MARK: - Actions

    @objc private func done() {
        commitFields()
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        commitFields()
    }

    private func commitFields() {
        config.apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        let url = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.baseURL = url.isEmpty ? "https://api.openai.com/v1" : url

        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.model = model.isEmpty ? "whisper-1" : model

        config.language = languageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        do { try config.save() }
        catch { NSLog("personal-stt: config save failed: %@", error.localizedDescription) }
        onChange()
    }

    // MARK: - Lifecycle

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
