import XCTest
@testable import AudioMeshCore

final class AudioMeshPacketTests: XCTestCase {
    func testRoundTripEncoding() throws {
        let payload = Data([1, 2, 3, 4])
        let packet = AudioMeshPacket(
            sequenceNumber: 42,
            timestamp: 96_000,
            ssrc: 1234,
            payload: payload
        )

        let decoded = try AudioMeshPacket.decode(packet.encode())

        XCTAssertEqual(decoded.sequenceNumber, 42)
        XCTAssertEqual(decoded.timestamp, 96_000)
        XCTAssertEqual(decoded.ssrc, 1234)
        XCTAssertEqual(decoded.payload, payload)
    }

    func testRejectsUnexpectedPayloadSize() throws {
        let packet = AudioMeshPacket(
            sequenceNumber: 1,
            timestamp: 2,
            ssrc: 3,
            payload: Data([1, 2])
        )

        XCTAssertThrowsError(try AudioMeshPacket.decode(packet.encode(), expectedPayloadBytes: 4)) { error in
            XCTAssertEqual(
                error as? AudioMeshPacketError,
                .invalidPayloadSize(expected: 4, actual: 2)
            )
        }
    }
}

