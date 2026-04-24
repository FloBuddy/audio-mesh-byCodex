import Foundation

public struct AudioMeshService: Sendable, Equatable {
    public static let serviceType = "_audiomesh._udp."
    public static let defaultMulticastGroup = "239.255.42.99"

    public let name: String
    public let hostName: String?
    public let port: UInt16
    public let transport: String
    public let group: String?
    public let sampleRate: Int
    public let channels: Int
    public let controlPort: UInt16?

    public init(
        name: String,
        hostName: String?,
        port: UInt16,
        transport: String,
        group: String?,
        sampleRate: Int,
        channels: Int,
        controlPort: UInt16?
    ) {
        self.name = name
        self.hostName = hostName
        self.port = port
        self.transport = transport
        self.group = group
        self.sampleRate = sampleRate
        self.channels = channels
        self.controlPort = controlPort
    }
}

public final class AudioMeshServiceAdvertiser: NSObject, NetServiceDelegate {
    private let service: NetService

    public init(
        name: String,
        port: UInt16,
        format: AudioMeshFormat,
        transport: String,
        group: String?,
        controlPort: UInt16? = nil
    ) {
        service = NetService(
            domain: "local.",
            type: AudioMeshService.serviceType,
            name: name,
            port: Int32(port)
        )

        var txt: [String: Data] = [
            "version": Data("1".utf8),
            "transport": Data(transport.utf8),
            "sampleRate": Data(String(format.sampleRate).utf8),
            "channels": Data(String(format.channels).utf8),
            "framesPerPacket": Data(String(format.framesPerPacket).utf8)
        ]

        if let group {
            txt["group"] = Data(group.utf8)
        }

        if let controlPort {
            txt["controlPort"] = Data(String(controlPort).utf8)
        }

        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        super.init()
        service.delegate = self
    }

    public func start() {
        service.publish()
    }

    public func stop() {
        service.stop()
    }

    public func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour published \(sender.name) as \(sender.type)local. on port \(sender.port)")
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("Bonjour publish failed: \(errorDict)")
    }
}

public final class AudioMeshServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var resolved: [AudioMeshService] = []

    public override init() {
        super.init()
        browser.delegate = self
    }

    public func discover(timeout: TimeInterval = 3) -> [AudioMeshService] {
        resolved = []
        services = []
        browser.searchForServices(ofType: AudioMeshService.serviceType, inDomain: "local.")
        RunLoop.current.run(until: Date().addingTimeInterval(timeout))
        browser.stop()
        return resolved
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 2)
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        let txt = NetService.dictionary(fromTXTRecord: sender.txtRecordData() ?? Data())

        let transport = txt.stringValue(for: "transport") ?? "unicast"
        let group = txt.stringValue(for: "group")
        let sampleRate = txt.intValue(for: "sampleRate") ?? AudioMeshFormat().sampleRate
        let channels = txt.intValue(for: "channels") ?? AudioMeshFormat().channels
        let controlPort = txt.intValue(for: "controlPort").flatMap(UInt16.init)

        let service = AudioMeshService(
            name: sender.name,
            hostName: sender.hostName,
            port: UInt16(sender.port),
            transport: transport,
            group: group,
            sampleRate: sampleRate,
            channels: channels,
            controlPort: controlPort
        )

        if !resolved.contains(service) {
            resolved.append(service)
        }
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("Bonjour resolve failed for \(sender.name): \(errorDict)")
    }
}

private extension Dictionary where Key == String, Value == Data {
    func stringValue(for key: String) -> String? {
        guard let data = self[key] else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func intValue(for key: String) -> Int? {
        guard let value = stringValue(for: key) else {
            return nil
        }
        return Int(value)
    }
}
