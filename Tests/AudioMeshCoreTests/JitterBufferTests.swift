import XCTest
@testable import AudioMeshCore

final class JitterBufferTests: XCTestCase {
    func testBuffersThenReturnsPacketsInSequenceOrder() {
        var buffer = JitterBuffer(prebufferPacketCount: 3)

        buffer.push(packet(sequence: 3))
        XCTAssertNil(buffer.popReady())

        buffer.push(packet(sequence: 1))
        XCTAssertNil(buffer.popReady())

        buffer.push(packet(sequence: 2))
        XCTAssertEqual(buffer.popReady()?.sequenceNumber, 1)
        XCTAssertEqual(buffer.popReady()?.sequenceNumber, 2)
        XCTAssertEqual(buffer.popReady()?.sequenceNumber, 3)
        XCTAssertNil(buffer.popReady())
    }

    func testReportsQueuedDuration() {
        let format = AudioMeshFormat()
        var buffer = JitterBuffer(prebufferPacketCount: 3)

        buffer.push(packet(sequence: 1))
        buffer.push(packet(sequence: 2))

        XCTAssertEqual(buffer.queuedDurationMilliseconds(format: format), 40, accuracy: 0.001)
    }

    private func packet(sequence: UInt16) -> AudioMeshPacket {
        AudioMeshPacket(
            sequenceNumber: sequence,
            timestamp: UInt32(sequence) * 960,
            ssrc: 1,
            payload: Data([UInt8(sequence & 0xff)])
        )
    }
}
