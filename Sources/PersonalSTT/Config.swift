import Foundation

/// Live config — reads/writes ~/.config/personal-stt/config.json.
/// Class (not struct) so the same instance can be mutated from Settings
/// and re-read by Transcriber on every request.
final class Config {
    var apiKey: String
    var baseURL: String
    var model: String
    var language: String

    private static let configURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/personal-stt/config.json")

    init(apiKey: String, baseURL: String, model: String, language: String) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.language = language
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
            apiKey:   val("OPENAI_API_KEY",          "api_key",  ""),
            baseURL:  val("OPENAI_BASE_URL",         "base_url", "https://api.openai.com/v1"),
            model:    val("OPENAI_WHISPER_MODEL",    "model",    "whisper-1"),
            language: val("OPENAI_WHISPER_LANGUAGE", "language", "ru")
        )
    }

    func save() throws {
        let dir = Self.configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dict: [String: String] = [
            "api_key":  apiKey,
            "base_url": baseURL,
            "model":    model,
            "language": language,
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Self.configURL, options: [.atomic])

        // Private — contains the API key.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.configURL.path)
    }

    static var configFileURL: URL { configURL }
}
