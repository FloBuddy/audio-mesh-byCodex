import Foundation

public struct AudioMeshFormat: Sendable, Equatable {
    public let sampleRate: Int
    public let channels: Int
    public let framesPerPacket: Int

    public init(sampleRate: Int = 48_000, channels: Int = 2, framesPerPacket: Int = 960) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.framesPerPacket = framesPerPacket
    }

    public var packetDurationSeconds: Double {
        Double(framesPerPacket) / Double(sampleRate)
    }

    public var payloadByteCount: Int {
        framesPerPacket * channels * MemoryLayout<Float32>.size
    }
}

