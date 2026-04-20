import AppKit
import CoreGraphics

/// Injects text directly into the currently focused input field of the frontmost app
/// via synthesized keyboard events. Clipboard is not touched.
enum TextInjector {
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        // CGEvent keyboard events can carry arbitrary UTF-16 strings; the OS delivers
        // them to the focused responder as typed input.
        let utf16 = Array(text.utf16)

        // Some apps have input fields that cap the per-event string length (~20 chars),
        // so chunk into pieces of 16 UTF-16 units.
        let chunkSize = 16
        var index = 0
        while index < utf16.count {
            let end = min(index + chunkSize, utf16.count)
            let slice = Array(utf16[index..<end])

            if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                down.flags = []
                slice.withUnsafeBufferPointer { buf in
                    down.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: buf.baseAddress)
                }
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                up.flags = []
                slice.withUnsafeBufferPointer { buf in
                    up.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: buf.baseAddress)
                }
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
            index = end
        }
    }
}
