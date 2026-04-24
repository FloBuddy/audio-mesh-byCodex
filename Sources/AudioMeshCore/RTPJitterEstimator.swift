import Foundation

public struct RTPJitterEstimator: Sendable, Equatable {
    private var previousTransitTicks: Double?
    private var jitterTicks: Double = 0
    private var sampleRate = AudioMeshFormat().sampleRate

    public private(set) var observedPacketCount = 0

    public init() {}

    public var jitterMilliseconds: Double {
        jitterTicks / Double(sampleRate) * 1_000
    }

    public mutating func observe(
        packet: AudioMeshPacket,
        arrivalTime: TimeInterval,
        sampleRate: Int
    ) {
        self.sampleRate = sampleRate
        let arrivalTicks = arrivalTime * Double(sampleRate)
        let transitTicks = arrivalTicks - Double(packet.timestamp)
        observedPacketCount += 1

        guard let previousTransitTicks else {
            self.previousTransitTicks = transitTicks
            return
        }

        let delta = abs(transitTicks - previousTransitTicks)
        jitterTicks += (delta - jitterTicks) / 16
        self.previousTransitTicks = transitTicks
    }
}
