import XCTest
@testable import AudioMeshCore

final class RTPJitterEstimatorTests: XCTestCase {
    func testJitterRemainsZeroForStablePacketSpacing() {
        let format = AudioMeshFormat()
        var estimator = RTPJitterEstimator()

        estimator.observe(packet: packet(sequence: 0, timestamp: 0), arrivalTime: 0, sampleRate: format.sampleRate)
        estimator.observe(packet: packet(sequence: 1, timestamp: 960), arrivalTime: 0.020, sampleRate: format.sampleRate)
        estimator.observe(packet: packet(sequence: 2, timestamp: 1_920), arrivalTime: 0.040, sampleRate: format.sampleRate)

        XCTAssertEqual(estimator.observedPacketCount, 3)
        XCTAssertEqual(estimator.jitterMilliseconds, 0, accuracy: 0.001)
    }

    func testJitterTracksArrivalVariation() {
        let format = AudioMeshFormat()
        var estimator = RTPJitterEstimator()

        estimator.observe(packet: packet(sequence: 0, timestamp: 0), arrivalTime: 0, sampleRate: format.sampleRate)
        estimator.observe(packet: packet(sequence: 1, timestamp: 960), arrivalTime: 0.030, sampleRate: format.sampleRate)

        XCTAssertEqual(estimator.jitterMilliseconds, 0.625, accuracy: 0.001)
    }

    private func packet(sequence: UInt16, timestamp: UInt32) -> AudioMeshPacket {
        AudioMeshPacket(
            sequenceNumber: sequence,
            timestamp: timestamp,
            ssrc: 42,
            payload: Data()
        )
    }
}
