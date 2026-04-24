import Darwin
import Foundation

public enum AudioMeshControlError: Error {
    case createFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case acceptFailed(errno: Int32)
    case resolveFailed(String)
    case connectFailed(errno: Int32)
    case sendFailed(errno: Int32)
    case invalidRequest(String)
}

public final class AudioMeshControlServer {
    private let fileDescriptor: Int32
    private let onStart: @Sendable (String, UInt16) -> Void
    private var isRunning = true

    public init(port: UInt16, onStart: @escaping @Sendable (String, UInt16) -> Void) throws {
        self.onStart = onStart
        fileDescriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fileDescriptor >= 0 else {
            throw AudioMeshControlError.createFailed(errno: errno)
        }

        var reuse: Int32 = 1
        setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr(s_addr: INADDR_ANY.bigEndian),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(fileDescriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(fileDescriptor)
            throw AudioMeshControlError.bindFailed(errno: errno)
        }

        guard listen(fileDescriptor, 8) == 0 else {
            close(fileDescriptor)
            throw AudioMeshControlError.listenFailed(errno: errno)
        }
    }

    deinit {
        stop()
    }

    public func start() {
        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        isRunning = false
        close(fileDescriptor)
    }

    private func acceptLoop() {
        while isRunning {
            var peerAddress = sockaddr_in()
            var peerLength = socklen_t(MemoryLayout<sockaddr_in>.size)

            let client = withUnsafeMutablePointer(to: &peerAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    Darwin.accept(fileDescriptor, socketAddress, &peerLength)
                }
            }

            guard client >= 0 else {
                continue
            }

            handle(client: client, peerAddress: peerAddress)
            close(client)
        }
    }

    private func handle(client: Int32, peerAddress: sockaddr_in) {
        var buffer = [UInt8](repeating: 0, count: 128)
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0,
              let request = String(bytes: buffer.prefix(count), encoding: .utf8) else {
            return
        }

        let parts = request.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count == 2,
              parts[0] == "START",
              let port = UInt16(parts[1]) else {
            return
        }

        let host = String(cString: inet_ntoa(peerAddress.sin_addr))
        onStart(host, port)
        _ = "OK\n".withCString { pointer in
            send(client, pointer, strlen(pointer), 0)
        }
    }
}

public struct AudioMeshControlClient {
    public init() {}

    public func requestStart(host: String, controlPort: UInt16, audioPort: UInt16) throws {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let resolveResult = getaddrinfo(host, String(controlPort), &hints, &result)
        guard resolveResult == 0, let result else {
            throw AudioMeshControlError.resolveFailed(host)
        }
        defer { freeaddrinfo(result) }

        let fileDescriptor = socket(result.pointee.ai_family, result.pointee.ai_socktype, result.pointee.ai_protocol)
        guard fileDescriptor >= 0 else {
            throw AudioMeshControlError.createFailed(errno: errno)
        }
        defer { close(fileDescriptor) }

        guard connect(fileDescriptor, result.pointee.ai_addr, result.pointee.ai_addrlen) == 0 else {
            throw AudioMeshControlError.connectFailed(errno: errno)
        }

        let request = "START \(audioPort)\n"
        let sent = request.withCString { pointer in
            send(fileDescriptor, pointer, strlen(pointer), 0)
        }

        guard sent == request.utf8.count else {
            throw AudioMeshControlError.sendFailed(errno: errno)
        }
    }
}

