import AppKit
import AVFoundation
import ApplicationServices

final class AppController: NSObject, NSApplicationDelegate {
    private let config = Config.load()
    private let audio = AudioCapture()
    private let overlay = RecordingOverlay()
    private let hotkey = Hotkey()
    private lazy var transcriber = Transcriber(config: config)
    private lazy var settings = SettingsWindowController(config: config) { }

    private var statusItem: NSStatusItem!
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSLog("personal-stt: launched, model=%@ lang=%@", config.model, config.language)

        setupMenu()
        requestMicPermission()
        requestAccessibilityPermission()

        hotkey.onStart = { [weak self] in self?.startRecording() }
        hotkey.onStop  = { [weak self] in self?.stopAndTranscribe() }
        hotkey.start()

        if config.apiKey.isEmpty {
            NSLog("personal-stt: OPENAI_API_KEY is empty — open Settings to set it")
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "🎙"
            btn.toolTip = "personal-stt"
        }

        let menu = NSMenu()

        let header = NSMenuItem(title: "personal-stt", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit personal-stt", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openSettings() { settings.show() }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Recording pipeline

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                NSLog("personal-stt: microphone access denied")
            }
        }
    }

    /// Triggers the Accessibility permission prompt eagerly on launch — otherwise
    /// macOS only shows it the first time we try to post synthesized keystrokes,
    /// which means the first transcription silently fails because the permission
    /// dialog appears too late to gate the CGEvent post.
    private func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("personal-stt: accessibility trusted = %@",
              trusted ? "yes" : "no (system prompt shown)")
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
                // Log BEFORE injection — if focus has drifted and the keystrokes
                // land nowhere, the transcript is still preserved on disk.
                TranscriptLog.record(text)
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
