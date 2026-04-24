import XCTest
@testable import AudioMeshCore

final class AudioMeshControlTests: XCTestCase {
    func testClientRequestsStart() throws {
        let expectation = expectation(description: "server receives START request")
        let port = UInt16(15_505)
        let capture = ControlRequestCapture()

        let server = try AudioMeshControlServer(port: port) { host, audioPort in
            capture.set(host: host, port: audioPort)
            expectation.fulfill()
        }

        server.start()
        try AudioMeshControlClient().requestStart(
            host: "127.0.0.1",
            controlPort: port,
            audioPort: 5_004
        )

        wait(for: [expectation], timeout: 2)
        server.stop()

        XCTAssertEqual(capture.host, "127.0.0.1")
        XCTAssertEqual(capture.port, 5_004)
    }
}

private final class ControlRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var value: (host: String, port: UInt16)?

    var host: String? {
        lock.lock()
        defer { lock.unlock() }
        return value?.host
    }

    var port: UInt16? {
        lock.lock()
        defer { lock.unlock() }
        return value?.port
    }

    func set(host: String, port: UInt16) {
        lock.lock()
        value = (host, port)
        lock.unlock()
    }
}
