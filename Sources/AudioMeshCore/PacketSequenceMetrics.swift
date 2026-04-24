import Foundation

public struct PacketSequenceMetrics: Sendable, Equatable {
    public private(set) var receivedPacketCount = 0
    public private(set) var missingPacketCount = 0
    public private(set) var reorderedOrDuplicatePacketCount = 0
    private var highestSequenceNumber: UInt16?

    public init() {}

    public mutating func observe(sequenceNumber: UInt16) {
        receivedPacketCount += 1

        guard let highestSequenceNumber else {
            self.highestSequenceNumber = sequenceNumber
            return
        }

        let forwardDistance = sequenceNumber &- highestSequenceNumber

        if forwardDistance == 0 {
            reorderedOrDuplicatePacketCount += 1
        } else if forwardDistance < UInt16.max / 2 {
            missingPacketCount += max(0, Int(forwardDistance) - 1)
            self.highestSequenceNumber = sequenceNumber
        } else {
            reorderedOrDuplicatePacketCount += 1
        }
    }
}

