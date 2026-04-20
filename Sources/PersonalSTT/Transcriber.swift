import Foundation

final class Transcriber {
    private let config: Config

    init(config: Config) { self.config = config }

    func transcribe(wav: Data) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw NSError(domain: "Transcriber", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY not set"])
        }

        let url = URL(string: "\(config.baseURL)/audio/transcriptions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "----PersonalSTT-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func fileField(_ name: String, _ filename: String, _ mime: String, _ data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        fileField("file", "audio.wav", "audio/wav", wav)
        field("model", config.model)
        field("language", config.language)
        field("response_format", "text")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        NSLog("personal-stt: POST %@ (wav=%d bytes, model=%@, lang=%@)",
              url.absoluteString, wav.count, config.model, config.language)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "Transcriber", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }
        if http.statusCode < 200 || http.statusCode >= 300 {
            let txt = String(data: data, encoding: .utf8) ?? "?"
            throw NSError(domain: "Transcriber", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Whisper HTTP \(http.statusCode): \(txt)"])
        }
        let text = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("personal-stt: whisper → %d chars: %@",
              text.count, String(text.prefix(120)))
        return text
    }
}
