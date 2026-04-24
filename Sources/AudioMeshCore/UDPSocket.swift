import Darwin
import Foundation

public enum UDPSocketError: Error {
    case createFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case sendFailed(errno: Int32)
    case receiveFailed(errno: Int32)
    case invalidHost(String)
}

public final class UDPSender {
    private let fileDescriptor: Int32
    private var address: sockaddr_in

    public init(host: String, port: UInt16) throws {
        fileDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fileDescriptor >= 0 else {
            throw UDPSocketError.createFailed(errno: errno)
        }

        var resolved = in_addr()
        guard inet_pton(AF_INET, host, &resolved) == 1 else {
            close(fileDescriptor)
            throw UDPSocketError.invalidHost(host)
        }

        address = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: resolved,
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    deinit {
        close(fileDescriptor)
    }

    public func send(_ data: Data) throws {
        let sent = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    Darwin.sendto(
                        fileDescriptor,
                        buffer.baseAddress,
                        buffer.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        guard sent == data.count else {
            throw UDPSocketError.sendFailed(errno: errno)
        }
    }
}

public final class UDPReceiver {
    private let fileDescriptor: Int32
    private let maxPacketSize: Int

    public init(port: UInt16, maxPacketSize: Int = 65_535) throws {
        self.maxPacketSize = maxPacketSize
        fileDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fileDescriptor >= 0 else {
            throw UDPSocketError.createFailed(errno: errno)
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

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(fileDescriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard result == 0 else {
            close(fileDescriptor)
            throw UDPSocketError.bindFailed(errno: errno)
        }
    }

    deinit {
        close(fileDescriptor)
    }

    public func receive() throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxPacketSize)
        let count = Darwin.recv(fileDescriptor, &buffer, buffer.count, 0)
        guard count >= 0 else {
            throw UDPSocketError.receiveFailed(errno: errno)
        }
        return Data(buffer.prefix(count))
    }
}

