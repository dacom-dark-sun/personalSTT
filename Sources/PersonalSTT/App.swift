import AppKit
import AVFoundation

final class AppController: NSObject, NSApplicationDelegate {
    private let config = Config.load()
    private let audio = AudioCapture()
    private let overlay = RecordingOverlay()
    private lazy var transcriber = Transcriber(config: config)
    private lazy var hotkey = Hotkey(spec: config.hotkey)

    private var statusItem: NSStatusItem!
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSLog("personal-stt: launched, hotkey=%@ model=%@ lang=%@",
              config.hotkeyRaw, config.model, config.language)

        setupMenu()
        requestMicPermission()

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.stopAndTranscribe() }
        hotkey.start()

        if config.apiKey.isEmpty {
            NSLog("personal-stt: OPENAI_API_KEY is empty — set it via the menu or config.json")
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "🎙"
            btn.toolTip = "personal-stt — hold hotkey to dictate"
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "personal-stt", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(makeEditItem(
            title: "API Key",
            preview: maskKey(config.apiKey),
            selector: #selector(editApiKey)
        ))
        menu.addItem(makeEditItem(
            title: "Base URL",
            preview: config.baseURL,
            selector: #selector(editBaseURL)
        ))
        menu.addItem(makeEditItem(
            title: "Model",
            preview: config.model,
            selector: #selector(editModel)
        ))
        menu.addItem(makeEditItem(
            title: "Language",
            preview: config.language,
            selector: #selector(editLanguage)
        ))

        let hotkeySubItem = NSMenuItem(title: "Hotkey: \(config.hotkeyRaw)", action: nil, keyEquivalent: "")
        let hotkeySub = NSMenu()
        for choice in HotkeySpec.choices {
            let item = NSMenuItem(title: choice.title, action: #selector(pickHotkey(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.value
            if choice.value == config.hotkeyRaw { item.state = .on }
            hotkeySub.addItem(item)
        }
        hotkeySubItem.submenu = hotkeySub
        menu.addItem(hotkeySubItem)

        menu.addItem(.separator())

        let testItem = NSMenuItem(title: "Test text injection", action: #selector(testInjection), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)

        let revealItem = NSMenuItem(title: "Reveal config.json in Finder", action: #selector(revealConfig), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let consoleItem = NSMenuItem(title: "Open Console (live logs)", action: #selector(openConsole), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(consoleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit personal-stt", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeEditItem(title: String, preview: String, selector: Selector) -> NSMenuItem {
        let display = preview.isEmpty ? "(not set)" : preview
        let item = NSMenuItem(title: "\(title): \(display)", action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func maskKey(_ key: String) -> String {
        guard !key.isEmpty else { return "" }
        if key.count <= 10 { return String(repeating: "•", count: key.count) }
        let tail = key.suffix(4)
        return "••••••••\(tail)"
    }

    // MARK: - Editing

    @objc private func editApiKey() {
        promptEdit(title: "OpenAI API Key",
                   message: "Stored in ~/.config/personal-stt/config.json (chmod 600).",
                   current: config.apiKey,
                   secure: true) { [weak self] newValue in
            self?.config.apiKey = newValue
            self?.saveAndRefresh()
        }
    }

    @objc private func editBaseURL() {
        promptEdit(title: "Base URL",
                   message: "OpenAI-compatible endpoint. Default: https://api.openai.com/v1",
                   current: config.baseURL,
                   secure: false) { [weak self] newValue in
            self?.config.baseURL = newValue.isEmpty ? "https://api.openai.com/v1" : newValue
            self?.saveAndRefresh()
        }
    }

    @objc private func editModel() {
        promptEdit(title: "Whisper Model",
                   message: "e.g. whisper-1",
                   current: config.model,
                   secure: false) { [weak self] newValue in
            self?.config.model = newValue.isEmpty ? "whisper-1" : newValue
            self?.saveAndRefresh()
        }
    }

    @objc private func editLanguage() {
        promptEdit(title: "Language (ISO 639-1)",
                   message: "e.g. ru, en, de. Leave blank to let Whisper auto-detect.",
                   current: config.language,
                   secure: false) { [weak self] newValue in
            self?.config.language = newValue
            self?.saveAndRefresh()
        }
    }

    @objc private func pickHotkey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        config.updateHotkey(raw)
        hotkey.updateSpec(config.hotkey)
        saveAndRefresh()
    }

    private func saveAndRefresh() {
        do {
            try config.save()
            NSLog("personal-stt: config saved to %@", Config.configFileURL.path)
        } catch {
            NSLog("personal-stt: config save failed: %@", error.localizedDescription)
        }
        rebuildMenu()
    }

    private func promptEdit(title: String, message: String, current: String,
                             secure: Bool, onSave: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field: NSTextField = secure
            ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
            : NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.stringValue = current
        field.placeholderString = title
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            onSave(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Actions

    @objc private func testInjection() {
        let sample = "personal-stt test ✓"
        NSLog("personal-stt: test injection requested")
        // Give the user a moment to focus a target input.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            TextInjector.insert(sample)
        }
        let alert = NSAlert()
        alert.messageText = "Focus any input now"
        alert.informativeText = "Click OK, then focus a text input within 1.5 seconds — '\(sample)' will be typed into it."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func revealConfig() {
        // Ensure file exists first.
        if !FileManager.default.fileExists(atPath: Config.configFileURL.path) {
            try? config.save()
        }
        NSWorkspace.shared.activateFileViewerSelecting([Config.configFileURL])
    }

    @objc private func openConsole() {
        // Open Console.app with a predicate filtering to our process name.
        let script = """
        tell application "Console" to activate
        """
        if let s = NSAppleScript(source: script) { s.executeAndReturnError(nil) }
        NSLog("personal-stt: filter Console by 'PersonalSTT' or 'personal-stt' to see live logs")
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Recording pipeline

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                NSLog("personal-stt: microphone access denied")
            }
        }
    }

    private func startRecording() {
        guard !busy, !audio.isRecording else { return }
        do {
            try audio.start()
            Sounds.start()
            overlay.show()
            NSLog("personal-stt: recording started")
        } catch {
            Sounds.error()
            NSLog("personal-stt: recording failed: %@", error.localizedDescription)
        }
    }

    private func stopAndTranscribe() {
        guard audio.isRecording else { return }
        let wav = audio.stop()
        Sounds.stop()
        overlay.hide()

        guard let wav = wav, wav.count > 44 + 1600 else {
            NSLog("personal-stt: recording too short, skipping")
            return
        }
        NSLog("personal-stt: recording stopped, wav=%d bytes", wav.count)

        busy = true
        Task {
            defer { self.busy = false }
            do {
                let text = try await self.transcriber.transcribe(wav: wav)
                guard !text.isEmpty else {
                    NSLog("personal-stt: whisper returned empty text")
                    return
                }
                await MainActor.run { TextInjector.insert(text) }
            } catch {
                await MainActor.run {
                    Sounds.error()
                    NSLog("personal-stt: transcription failed: %@", error.localizedDescription)
                }
            }
        }
    }
}

@main
enum Main {
    static let controller = AppController()

    static func main() {
        let app = NSApplication.shared
        app.delegate = controller
        app.run()
    }
}
