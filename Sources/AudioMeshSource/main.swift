import AudioMeshCore
import Foundation

struct SourceOptions {
    var host = "127.0.0.1"
    var port: UInt16 = 5004
    var controlPort: UInt16 = 5005
    var frequency = 440.0
    var seconds: Double?
    var advertise = false
    var name = Host.current().localizedName ?? "Audio Mesh Source"
    var multicast = false
    var multicastGroup = AudioMeshService.defaultMulticastGroup
    var captureMode = CaptureMode.tone
    var codecID = AudioMeshCodecID.pcmFloat32
}

enum CaptureMode {
    case tone
    case screenAudio
}

func parseOptions() -> SourceOptions {
    var options = SourceOptions()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--host":
            if let value = iterator.next() {
                options.host = value
            }
        case "--port":
            if let value = iterator.next(), let port = UInt16(value) {
                options.port = port
            }
        case "--control-port":
            if let value = iterator.next(), let port = UInt16(value) {
                options.controlPort = port
            }
        case "--frequency":
            if let value = iterator.next(), let frequency = Double(value) {
                options.frequency = frequency
            }
        case "--seconds":
            if let value = iterator.next(), let seconds = Double(value) {
                options.seconds = seconds
            }
        case "--advertise":
            options.advertise = true
        case "--name":
            if let value = iterator.next() {
                options.name = value
            }
        case "--multicast":
            options.multicast = true
            options.host = options.multicastGroup
            options.advertise = true
        case "--group":
            if let value = iterator.next() {
                options.multicastGroup = value
                if options.multicast {
                    options.host = value
                }
            }
        case "--screen-audio":
            options.captureMode = .screenAudio
        case "--codec":
            if let value = iterator.next() {
                do {
                    options.codecID = try AudioMeshCodecFactory.parse(value)
                } catch {
                    print("Unsupported codec \"\(value)\". Supported: \(AudioMeshCodecID.allCases.map(\.rawValue).joined(separator: ", "))")
                    exit(2)
                }
            }
        case "--help", "-h":
            print("""
            Usage: audiomesh-source [--host 127.0.0.1] [--port 5004] [--frequency 440] [--seconds 10]
                                    [--advertise] [--name "Studio Mac"] [--control-port 5005]
                                    [--multicast] [--group 239.255.42.99] [--screen-audio]
                                    [--codec pcm-f32]

            Sends a 48 kHz stereo Float32 test tone using Audio Mesh RTP-style UDP packets.
            With --screen-audio, captures macOS system audio through ScreenCaptureKit.
            When --advertise is used without --multicast, receivers can request unicast via the control port.
            """)
            exit(0)
        default:
            break
        }
    }

    return options
}

final class DestinationStore {
    private let lock = NSLock()
    private var destination: (host: String, port: UInt16)?

    init(initial: (host: String, port: UInt16)?) {
        destination = initial
    }

    func set(host: String, port: UInt16) {
        lock.lock()
        destination = (host, port)
        lock.unlock()
    }

    func get() -> (host: String, port: UInt16)? {
        lock.lock()
        defer { lock.unlock() }
        return destination
    }
}

protocol PayloadSource {
    mutating func nextPayload() -> Data?
}

struct TonePayloadSource: PayloadSource {
    private var source: SineWaveSource

    init(format: AudioMeshFormat, frequency: Double) {
        source = SineWaveSource(format: format, frequency: frequency)
    }

    mutating func nextPayload() -> Data? {
        source.nextPayload()
    }
}

@available(macOS 13.0, *)
struct ScreenAudioPayloadSource: PayloadSource {
    private let source: ScreenAudioCaptureSource

    init(format: AudioMeshFormat) async throws {
        source = ScreenAudioCaptureSource(format: format)
        try await source.start()
    }

    mutating func nextPayload() -> Data? {
        source.nextPayload()
    }
}

@main
struct AudioMeshSourceCommand {
    static func main() async throws {
let options = parseOptions()
let format = AudioMeshFormat()
let destinationStore = DestinationStore(
    initial: options.advertise && !options.multicast ? nil : (options.host, options.port)
)
let controlServer = options.advertise && !options.multicast
    ? try AudioMeshControlServer(port: options.controlPort) { host, port in
        destinationStore.set(host: host, port: port)
        print("Receiver requested unicast stream: \(host):\(port)")
    }
    : nil
let advertiser = options.advertise
    ? AudioMeshServiceAdvertiser(
        name: options.name,
        port: options.port,
        format: format,
        transport: options.multicast ? "multicast" : "unicast",
        group: options.multicast ? options.multicastGroup : nil,
        controlPort: options.multicast ? nil : options.controlPort,
        codecID: options.codecID
    )
    : nil
let ssrc = UInt32.random(in: 1...UInt32.max)
let started = Date()
var sequenceNumber: UInt16 = 0
var timestamp: UInt32 = 0
var cachedDestination: (host: String, port: UInt16)?
var cachedSender: UDPSender?
var payloadSource = try await makePayloadSource(options: options, format: format)
let encoder = AudioMeshCodecFactory.makeEncoder(codecID: options.codecID)

controlServer?.start()
advertiser?.start()
if options.advertise && !options.multicast {
    print("Audio Mesh source waiting for receiver requests on TCP port \(options.controlPort)")
} else {
    switch options.captureMode {
    case .tone:
        print("Audio Mesh source sending \(options.frequency) Hz tone to \(options.host):\(options.port)")
    case .screenAudio:
        print("Audio Mesh source sending captured system audio to \(options.host):\(options.port)")
    }
}
if options.captureMode == .screenAudio {
    print("Capture mode: ScreenCaptureKit system audio")
}
print("Codec: \(options.codecID.rawValue)")
if options.advertise {
    print("Advertising source as \"\(options.name)\"")
}

while true {
    pumpRunLoop()

    if let seconds = options.seconds, Date().timeIntervalSince(started) >= seconds {
        break
    }

    guard let pcmPayload = payloadSource.nextPayload() else {
        break
    }
    let payload = try encoder.encode(pcmPayload: pcmPayload)

    let packet = AudioMeshPacket(
        sequenceNumber: sequenceNumber,
        timestamp: timestamp,
        ssrc: ssrc,
        payload: payload
    )

    if let destination = destinationStore.get() {
        if cachedDestination?.host != destination.host || cachedDestination?.port != destination.port {
            cachedSender = try UDPSender(
                host: destination.host,
                port: destination.port,
                multicastTTL: options.multicast ? 1 : nil
            )
            cachedDestination = destination
            print("Streaming to \(destination.host):\(destination.port)")
        }

        try cachedSender?.send(packet.encode())
    }

    sequenceNumber &+= 1
    timestamp &+= UInt32(format.framesPerPacket)
    try await Task.sleep(nanoseconds: UInt64(format.packetDurationSeconds * 1_000_000_000))
}

advertiser?.stop()
controlServer?.stop()
print("Audio Mesh source stopped")
    }

    private static func makePayloadSource(options: SourceOptions, format: AudioMeshFormat) async throws -> any PayloadSource {
        switch options.captureMode {
        case .tone:
            return TonePayloadSource(format: format, frequency: options.frequency)
        case .screenAudio:
            if #available(macOS 13.0, *) {
                return try await ScreenAudioPayloadSource(format: format)
            } else {
                throw SourceError.screenAudioRequiresMacOS13
            }
        }
    }
}

private func pumpRunLoop() {
    RunLoop.current.run(mode: .default, before: Date())
}

enum SourceError: Error {
    case screenAudioRequiresMacOS13
}
