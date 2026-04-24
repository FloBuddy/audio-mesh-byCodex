import XCTest
@testable import AudioMeshCore

final class AudioCodecTests: XCTestCase {
    func testPCMFloat32CodecRoundTripsPayload() throws {
        let codec = PCMFloat32Codec()
        let payload = Data([0, 0, 0, 0, 1, 2, 3, 4])

        let encoded = try codec.encode(pcmPayload: payload)
        let decoded = try codec.decode(encodedPayload: encoded)

        XCTAssertEqual(decoded, payload)
    }

    func testPCMFloat32CodecRejectsMisalignedPayload() {
        let codec = PCMFloat32Codec()

        XCTAssertThrowsError(try codec.encode(pcmPayload: Data([1, 2, 3]))) { error in
            XCTAssertEqual(
                error as? AudioMeshCodecError,
                .invalidPCMByteCount(expectedMultiple: 4, actual: 3)
            )
        }
    }

    func testCodecFactoryParsesKnownCodec() throws {
        XCTAssertEqual(try AudioMeshCodecFactory.parse("pcm-f32"), .pcmFloat32)
    }
}

