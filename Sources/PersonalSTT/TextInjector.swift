import AppKit
import CoreGraphics

/// Injects text directly into the focused input field of the frontmost app.
/// Uses the HID event tap with an explicit HID event source — the same recipe
/// used by Espanso, Alfred, etc. Clipboard is not touched.
enum TextInjector {
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        NSLog("personal-stt: injecting %d chars into %@", text.count, frontApp)

        let utf16 = Array(text.utf16)

        // CGEvent's keyboardSetUnicodeString is documented to accept strings up
        // to 20 UTF-16 units per event; some apps truncate silently, so chunk.
        let chunkSize = 16
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            NSLog("personal-stt: CGEventSource creation failed")
            return
        }

        var index = 0
        while index < utf16.count {
            let end = min(index + chunkSize, utf16.count)
            let slice = Array(utf16[index..<end])

            guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            else {
                NSLog("personal-stt: CGEvent creation failed")
                return
            }
            down.flags = []
            up.flags = []

            slice.withUnsafeBufferPointer { buf in
                down.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: buf.baseAddress)
                up.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: buf.baseAddress)
            }

            down.post(tap: .cghidEventTap)
            // 1 ms gap — some Electron-based apps drop the keyUp if it arrives
            // in the same run-loop tick as the keyDown.
            usleep(1_000)
            up.post(tap: .cghidEventTap)

            index = end
        }
    }
}
