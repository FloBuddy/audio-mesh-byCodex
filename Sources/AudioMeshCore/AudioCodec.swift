import Foundation

public enum AudioMeshCodecID: String, Sendable, CaseIterable {
    case pcmFloat32 = "pcm-f32"
}

public enum AudioMeshCodecError: Error, Equatable {
    case unsupportedCodec(String)
    case invalidPCMByteCount(expectedMultiple: Int, actual: Int)
}

public protocol AudioMeshEncoder {
    var codecID: AudioMeshCodecID { get }
    func encode(pcmPayload: Data) throws -> Data
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
    public static func makeEncoder(codecID: AudioMeshCodecID) -> any AudioMeshEncoder {
        switch codecID {
        case .pcmFloat32:
            return PCMFloat32Codec()
        }
    }

    public static func makeDecoder(codecID: AudioMeshCodecID) -> any AudioMeshDecoder {
        switch codecID {
        case .pcmFloat32:
            return PCMFloat32Codec()
        }
    }

    public static func parse(_ rawValue: String) throws -> AudioMeshCodecID {
        guard let codecID = AudioMeshCodecID(rawValue: rawValue) else {
            throw AudioMeshCodecError.unsupportedCodec(rawValue)
        }
        return codecID
    }
}

