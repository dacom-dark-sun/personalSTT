import Foundation

/// Live config — reads/writes ~/.config/personal-stt/config.json.
/// Class (not struct) so the same instance can be mutated from the menu
/// and re-read by Transcriber on every request.
final class Config {
    var apiKey: String
    var baseURL: String
    var model: String
    var language: String
    var hotkey: HotkeySpec
    var hotkeyRaw: String

    private static let configURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/personal-stt/config.json")

    init(apiKey: String, baseURL: String, model: String, language: String, hotkeyRaw: String) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.language = language
        self.hotkeyRaw = hotkeyRaw
        self.hotkey = HotkeySpec.parse(hotkeyRaw)
    }

    static func load() -> Config {
        let env = ProcessInfo.processInfo.environment

        let fileDict: [String: Any] = (try? Data(contentsOf: configURL))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        func val(_ envKey: String, _ fileKey: String, _ fallback: String) -> String {
            if let v = env[envKey], !v.isEmpty { return v }
            if let v = fileDict[fileKey] as? String, !v.isEmpty { return v }
            return fallback
        }

        return Config(
            apiKey: val("OPENAI_API_KEY", "api_key", ""),
            baseURL: val("OPENAI_BASE_URL", "base_url", "https://api.openai.com/v1"),
            model: val("OPENAI_WHISPER_MODEL", "model", "whisper-1"),
            language: val("OPENAI_WHISPER_LANGUAGE", "language", "ru"),
            hotkeyRaw: val("PERSONAL_STT_HOTKEY", "hotkey", "right_option")
        )
    }

    func save() throws {
        let dir = Self.configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dict: [String: String] = [
            "api_key": apiKey,
            "base_url": baseURL,
            "model": model,
            "language": language,
            "hotkey": hotkeyRaw,
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Self.configURL, options: [.atomic])

        // Private: contains API key.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.configURL.path)
    }

    func updateHotkey(_ raw: String) {
        hotkeyRaw = raw
        hotkey = HotkeySpec.parse(raw)
    }

    static var configFileURL: URL { configURL }
}

struct HotkeySpec {
    let keyCode: UInt16?
    let modifierMask: UInt64

    /// For modifier-only hold we want: pressing THIS modifier alone starts recording; releasing stops.
    /// modifierMask is the CGEventFlags bit combination we look for.
    static func parse(_ s: String) -> HotkeySpec {
        switch s.lowercased() {
        case "right_option", "ropt", "right_alt":
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

    static let choices: [(title: String, value: String)] = [
        ("Right Option (⌥)", "right_option"),
        ("Left Option (⌥)", "left_option"),
        ("Right Control (⌃)", "right_control"),
        ("Right Command (⌘)", "right_command"),
        ("Fn", "fn"),
    ]
}
