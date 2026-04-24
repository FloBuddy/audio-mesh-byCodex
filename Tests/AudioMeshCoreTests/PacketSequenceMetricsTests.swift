import XCTest
@testable import AudioMeshCore

final class PacketSequenceMetricsTests: XCTestCase {
    func testTracksMissingPackets() {
        var metrics = PacketSequenceMetrics()

        metrics.observe(sequenceNumber: 1)
        metrics.observe(sequenceNumber: 2)
        metrics.observe(sequenceNumber: 5)

        XCTAssertEqual(metrics.receivedPacketCount, 3)
        XCTAssertEqual(metrics.missingPacketCount, 2)
        XCTAssertEqual(metrics.reorderedOrDuplicatePacketCount, 0)
    }

    func testTracksDuplicateAndReorderedPackets() {
        var metrics = PacketSequenceMetrics()

        metrics.observe(sequenceNumber: 10)
        metrics.observe(sequenceNumber: 10)
        metrics.observe(sequenceNumber: 9)

        XCTAssertEqual(metrics.receivedPacketCount, 3)
        XCTAssertEqual(metrics.missingPacketCount, 0)
        XCTAssertEqual(metrics.reorderedOrDuplicatePacketCount, 2)
    }
}

