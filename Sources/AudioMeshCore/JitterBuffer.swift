import Foundation

public struct JitterBuffer {
    private var packets: [UInt16: AudioMeshPacket] = [:]
    private var expectedSequenceNumber: UInt16?
    private let prebufferPacketCount: Int

    public init(prebufferPacketCount: Int = 8) {
        self.prebufferPacketCount = prebufferPacketCount
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
            self.expectedSequenceNumber = next &+ 1
            return packets.removeValue(forKey: next)
        }

        return nil
    }
}

