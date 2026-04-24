import COpus
import Foundation

public enum AudioMeshCodecID: String, Sendable, CaseIterable {
    case pcmFloat32 = "pcm-f32"
    case opus = "opus"
}

public enum AudioMeshCodecError: Error, Equatable {
    case unsupportedCodec(String)
    case invalidPCMByteCount(expectedMultiple: Int, actual: Int)
    case opusCreateFailed(Int32)
    case opusEncodeFailed(Int32)
    case opusDecodeFailed(Int32)
}

public protocol AudioMeshEncoder {
    var codecID: AudioMeshCodecID { get }
    func encode(pcmPayload: Data) throws -> Data
}

public final class OpusEncoder: AudioMeshEncoder {
    public let codecID = AudioMeshCodecID.opus
    private let format: AudioMeshFormat
    private let encoder: OpaquePointer
    private let maxPacketByteCount = 4_000

    public init(format: AudioMeshFormat) throws {
        self.format = format
        var error: Int32 = 0
        guard let encoder = opus_encoder_create(
            Int32(format.sampleRate),
            Int32(format.channels),
            OPUS_APPLICATION_AUDIO,
            &error
        ) else {
            throw AudioMeshCodecError.opusCreateFailed(error)
        }
        self.encoder = encoder
    }

    deinit {
        opus_encoder_destroy(encoder)
    }

    public func encode(pcmPayload: Data) throws -> Data {
        let expectedByteCount = format.payloadByteCount
        guard pcmPayload.count == expectedByteCount else {
            throw AudioMeshCodecError.invalidPCMByteCount(
                expectedMultiple: expectedByteCount,
                actual: pcmPayload.count
            )
        }

        var encoded = [UInt8](repeating: 0, count: maxPacketByteCount)
        let encodedByteCount = pcmPayload.withUnsafeBytes { pcmBuffer in
            encoded.withUnsafeMutableBufferPointer { encodedBuffer in
                opus_encode_float(
                    encoder,
                    pcmBuffer.bindMemory(to: Float.self).baseAddress!,
                    Int32(format.framesPerPacket),
                    encodedBuffer.baseAddress!,
                    Int32(maxPacketByteCount)
                )
            }
        }

        guard encodedByteCount >= 0 else {
            throw AudioMeshCodecError.opusEncodeFailed(encodedByteCount)
        }

        return Data(encoded.prefix(Int(encodedByteCount)))
    }
}

public final class OpusDecoder: AudioMeshDecoder {
    public let codecID = AudioMeshCodecID.opus
    private let format: AudioMeshFormat
    private let decoder: OpaquePointer

    public init(format: AudioMeshFormat) throws {
        self.format = format
        var error: Int32 = 0
        guard let decoder = opus_decoder_create(
            Int32(format.sampleRate),
            Int32(format.channels),
            &error
        ) else {
            throw AudioMeshCodecError.opusCreateFailed(error)
        }
        self.decoder = decoder
    }

    deinit {
        opus_decoder_destroy(decoder)
    }

    public func decode(encodedPayload: Data) throws -> Data {
        var pcm = [Float32](repeating: 0, count: format.framesPerPacket * format.channels)
        let decodedFrameCount = encodedPayload.withUnsafeBytes { encodedBuffer in
            pcm.withUnsafeMutableBufferPointer { pcmBuffer in
                opus_decode_float(
                    decoder,
                    encodedBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(encodedPayload.count),
                    pcmBuffer.baseAddress!,
                    Int32(format.framesPerPacket),
                    0
                )
            }
        }

        guard decodedFrameCount >= 0 else {
            throw AudioMeshCodecError.opusDecodeFailed(decodedFrameCount)
        }

        let sampleCount = Int(decodedFrameCount) * format.channels
        return pcm.withUnsafeBufferPointer { buffer in
            Data(buffer: UnsafeBufferPointer(start: buffer.baseAddress, count: sampleCount))
        }
    }
}

public protocol AudioMeshDecoder {
    var codecID: AudioMeshCodecID { get }
    func decode(encodedPayload: Data) throws -> Data
}

public struct PCMFloat32Codec: AudioMeshEncoder, AudioMeshDecoder, Sendable {
    public let codecID = AudioMeshCodecID.pcmFloat32
    private let bytesPerSample = MemoryLayout<Float32>.size

    public init() {}

    public func encode(pcmPayload: Data) throws -> Data {
        try validate(pcmPayload)
        return pcmPayload
    }

    public func decode(encodedPayload: Data) throws -> Data {
        try validate(encodedPayload)
        return encodedPayload
    }

    private func validate(_ payload: Data) throws {
        guard payload.count % bytesPerSample == 0 else {
            throw AudioMeshCodecError.invalidPCMByteCount(
                expectedMultiple: bytesPerSample,
                actual: payload.count
            )
        }
    }
}

public enum AudioMeshCodecFactory {
    public static func makeEncoder(codecID: AudioMeshCodecID, format: AudioMeshFormat = AudioMeshFormat()) throws -> any AudioMeshEncoder {
        switch codecID {
        case .pcmFloat32:
            return PCMFloat32Codec()
        case .opus:
            return try OpusEncoder(format: format)
        }
    }

    public static func makeDecoder(codecID: AudioMeshCodecID, format: AudioMeshFormat = AudioMeshFormat()) throws -> any AudioMeshDecoder {
        switch codecID {
        case .pcmFloat32:
            return PCMFloat32Codec()
        case .opus:
            return try OpusDecoder(format: format)
        }
    }

    public static func parse(_ rawValue: String) throws -> AudioMeshCodecID {
        guard let codecID = AudioMeshCodecID(rawValue: rawValue) else {
            throw AudioMeshCodecError.unsupportedCodec(rawValue)
        }
        return codecID
    }
}
