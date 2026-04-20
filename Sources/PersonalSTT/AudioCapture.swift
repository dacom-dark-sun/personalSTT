import Foundation
import AVFoundation

/// Captures default input device, converts to 16 kHz mono Int16 PCM, accumulates into a single WAV buffer.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat!
    private var pcmBytes = Data()
    private let lock = NSLock()

    private(set) var isRecording = false

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isRecording else { return }

        pcmBytes.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "AudioCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "AVAudioConverter init failed"])
        }
        converter = conv

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Returns the full recorded audio as a WAV file buffer (16 kHz mono 16-bit), or nil if empty.
    func stop() -> Data? {
        lock.lock()
        let wasRecording = isRecording
        isRecording = false
        lock.unlock()

        guard wasRecording else { return nil }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        lock.lock()
        let pcm = pcmBytes
        pcmBytes.removeAll(keepingCapacity: false)
        lock.unlock()

        guard !pcm.isEmpty else { return nil }
        return Self.wrapWAV(pcm: pcm, sampleRate: 16_000, channels: 1, bitsPerSample: 16)
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        // Target capacity — convert at ratio sr_out/sr_in
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outBuf, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil { return }

        let frames = Int(outBuf.frameLength)
        guard frames > 0, let ch = outBuf.int16ChannelData?[0] else { return }
        let byteCount = frames * MemoryLayout<Int16>.size

        ch.withMemoryRebound(to: UInt8.self, capacity: byteCount) { ptr in
            lock.lock()
            pcmBytes.append(ptr, count: byteCount)
            lock.unlock()
        }
    }

    private static func wrapWAV(pcm: Data, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
        let dataSize = UInt32(pcm.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.appendLE(UInt32(36 + dataSize))
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.appendLE(UInt32(16))
        header.appendLE(UInt16(1))         // PCM
        header.appendLE(channels)
        header.appendLE(sampleRate)
        header.appendLE(byteRate)
        header.appendLE(blockAlign)
        header.appendLE(bitsPerSample)
        header.append("data".data(using: .ascii)!)
        header.appendLE(dataSize)
        header.append(pcm)
        return header
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
