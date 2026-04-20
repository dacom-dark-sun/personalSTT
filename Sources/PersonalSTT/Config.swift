import Foundation

struct Config {
    let apiKey: String
    let baseURL: String
    let model: String
    let language: String
    let hotkey: HotkeySpec

    static func load() -> Config {
        let env = ProcessInfo.processInfo.environment

        let fileURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".config/personal-stt/config.json")
        let fileDict: [String: Any] = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        func val(_ envKey: String, _ fileKey: String, _ fallback: String) -> String {
            if let v = env[envKey], !v.isEmpty { return v }
            if let v = fileDict[fileKey] as? String, !v.isEmpty { return v }
            return fallback
        }

        let hotkeyStr = val("PERSONAL_STT_HOTKEY", "hotkey", "right_option")

        return Config(
            apiKey: val("OPENAI_API_KEY", "api_key", ""),
            baseURL: val("OPENAI_BASE_URL", "base_url", "https://api.openai.com/v1"),
            model: val("OPENAI_WHISPER_MODEL", "model", "whisper-1"),
            language: val("OPENAI_WHISPER_LANGUAGE", "language", "ru"),
            hotkey: HotkeySpec.parse(hotkeyStr)
        )
    }
}

struct HotkeySpec {
    /// Modifier-only hold (e.g. right option). `keyCode == nil` means modifier-hold mode.
    let keyCode: UInt16?
    let modifierMask: UInt64

    /// For modifier-only hold we want: pressing THIS modifier alone starts recording; releasing stops.
    /// modifierMask is the CGEventFlags bit we look for.
    static func parse(_ s: String) -> HotkeySpec {
        switch s.lowercased() {
        case "right_option", "ropt", "right_alt":
            // kCGEventFlagMaskAlternate (0x00080000) + device-dependent right-option bit (0x00000040)
            return HotkeySpec(keyCode: nil, modifierMask: 0x00080040)
        case "left_option", "lopt", "left_alt":
            return HotkeySpec(keyCode: nil, modifierMask: 0x00080020)
        case "right_control", "rctrl":
            return HotkeySpec(keyCode: nil, modifierMask: 0x00040042)
        case "right_command", "rcmd":
            return HotkeySpec(keyCode: nil, modifierMask: 0x00100010)
        case "fn":
            return HotkeySpec(keyCode: nil, modifierMask: 0x00800000)
        default:
            return HotkeySpec(keyCode: nil, modifierMask: 0x00080040)
        }
    }
}
