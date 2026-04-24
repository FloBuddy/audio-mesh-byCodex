import Foundation

public enum AudioMeshPacketError: Error, Equatable {
    case tooShort
    case unsupportedVersion(UInt8)
    case unsupportedPayloadType(UInt8)
    case invalidPayloadSize(expected: Int, actual: Int)
}

public struct AudioMeshPacket: Sendable, Equatable {
    public static let headerByteCount = 12
    public static let rtpVersion: UInt8 = 2
    public static let payloadType: UInt8 = 96

    public let sequenceNumber: UInt16
    public let timestamp: UInt32
    public let ssrc: UInt32
    public let payload: Data

    public init(sequenceNumber: UInt16, timestamp: UInt32, ssrc: UInt32, payload: Data) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.payload = payload
    }

    public func encode() -> Data {
        var data = Data(capacity: Self.headerByteCount + payload.count)
        data.append(Self.rtpVersion << 6)
        data.append(Self.payloadType)
        data.appendUInt16BE(sequenceNumber)
        data.appendUInt32BE(timestamp)
        data.appendUInt32BE(ssrc)
        data.append(payload)
        return data
    }

    public static func decode(_ data: Data, expectedPayloadBytes: Int? = nil) throws -> AudioMeshPacket {
        guard data.count >= Self.headerByteCount else {
            throw AudioMeshPacketError.tooShort
        }

        let version = data[data.startIndex] >> 6
        guard version == Self.rtpVersion else {
            throw AudioMeshPacketError.unsupportedVersion(version)
        }

        let payloadType = data[data.startIndex + 1] & 0x7f
        guard payloadType == Self.payloadType else {
            throw AudioMeshPacketError.unsupportedPayloadType(payloadType)
        }

        let sequenceNumber = data.readUInt16BE(at: 2)
        let timestamp = data.readUInt32BE(at: 4)
        let ssrc = data.readUInt32BE(at: 8)
        let payload = data.subdata(in: Self.headerByteCount..<data.count)

        if let expectedPayloadBytes, payload.count != expectedPayloadBytes {
            throw AudioMeshPacketError.invalidPayloadSize(expected: expectedPayloadBytes, actual: payload.count)
        }

        return AudioMeshPacket(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            ssrc: ssrc,
            payload: payload
        )
    }
}

private extension Data {
    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    func readUInt16BE(at offset: Int) -> UInt16 {
        (UInt16(self[startIndex + offset]) << 8) |
        UInt16(self[startIndex + offset + 1])
    }

    func readUInt32BE(at offset: Int) -> UInt32 {
        (UInt32(self[startIndex + offset]) << 24) |
        (UInt32(self[startIndex + offset + 1]) << 16) |
        (UInt32(self[startIndex + offset + 2]) << 8) |
        UInt32(self[startIndex + offset + 3])
    }
}

