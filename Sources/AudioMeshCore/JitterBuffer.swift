import Foundation

public struct JitterBuffer {
    private var packets: [UInt16: AudioMeshPacket] = [:]
    private var expectedSequenceNumber: UInt16?
    private let prebufferPacketCount: Int
    public private(set) var skippedPacketCount = 0

    public init(prebufferPacketCount: Int = 8) {
        self.prebufferPacketCount = prebufferPacketCount
    }

    public var queuedPacketCount: Int {
        packets.count
    }

    public func queuedDurationMilliseconds(format: AudioMeshFormat) -> Double {
        Double(queuedPacketCount) * format.packetDurationSeconds * 1_000
    }

    public mutating func push(_ packet: AudioMeshPacket) {
        packets[packet.sequenceNumber] = packet
        if expectedSequenceNumber == nil, packets.count >= prebufferPacketCount {
            expectedSequenceNumber = packets.keys.min()
        }
    }

    public mutating func popReady() -> AudioMeshPacket? {
        guard let expectedSequenceNumber else {
            return nil
        }

        if let packet = packets.removeValue(forKey: expectedSequenceNumber) {
            self.expectedSequenceNumber = expectedSequenceNumber &+ 1
            return packet
        }

        if packets.count >= prebufferPacketCount * 2, let next = packets.keys.min() {
            skippedPacketCount += Int(next &- expectedSequenceNumber)
            self.expectedSequenceNumber = next &+ 1
            return packets.removeValue(forKey: next)
        }

        return nil
    }
}
