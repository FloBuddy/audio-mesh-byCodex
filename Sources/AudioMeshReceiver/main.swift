import AudioMeshCore
import AVFoundation
import Foundation

struct ReceiverOptions {
    var port: UInt16 = 5004
    var prebufferPackets = 8
    var playAudio = true
    var discover = false
    var discoveryTimeout: TimeInterval = 3
    var multicastGroup: String?
    var seconds: Double?
    var statsInterval = 100
    var codecID: AudioMeshCodecID?
}

func parseOptions() -> ReceiverOptions {
    var options = ReceiverOptions()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--port":
            if let value = iterator.next(), let port = UInt16(value) {
                options.port = port
            }
        case "--prebuffer":
            if let value = iterator.next(), let packets = Int(value) {
                options.prebufferPackets = packets
            }
        case "--no-audio":
            options.playAudio = false
        case "--discover":
            options.discover = true
        case "--discovery-timeout":
            if let value = iterator.next(), let timeout = Double(value) {
                options.discoveryTimeout = timeout
            }
        case "--group":
            if let value = iterator.next() {
                options.multicastGroup = value
            }
        case "--seconds":
            if let value = iterator.next(), let seconds = Double(value) {
                options.seconds = seconds
            }
        case "--stats-interval":
            if let value = iterator.next(), let interval = Int(value) {
                options.statsInterval = max(1, interval)
            }
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
            Usage: audiomesh-receiver [--port 5004] [--prebuffer 8] [--no-audio]
                                      [--discover] [--discovery-timeout 3] [--group 239.255.42.99]
                                      [--seconds 10] [--stats-interval 100]
                                      [--codec pcm-f32]

            Receives Audio Mesh RTP-style UDP packets and plays 48 kHz stereo Float32 audio.
            """)
            exit(0)
        default:
            break
        }
    }

    return options
}

final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat

    init(meshFormat: AudioMeshFormat) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(meshFormat.sampleRate),
            channels: AVAudioChannelCount(meshFormat.channels),
            interleaved: false
        ) else {
            throw NSError(domain: "AudioMeshReceiver", code: 1)
        }

        self.format = format
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.play()
    }

    func schedule(payload: Data, meshFormat: AudioMeshFormat) {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(meshFormat.framesPerPacket)
        ) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(meshFormat.framesPerPacket)
        let sampleCount = meshFormat.framesPerPacket * meshFormat.channels

        payload.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: Float32.self).baseAddress,
                  let channelData = buffer.floatChannelData else {
                return
            }

            for frame in 0..<meshFormat.framesPerPacket {
                for channel in 0..<meshFormat.channels {
                    let sourceIndex = frame * meshFormat.channels + channel
                    if sourceIndex < sampleCount {
                        channelData[channel][frame] = baseAddress[sourceIndex]
                    }
                }
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}

let options = parseOptions()
let meshFormat = AudioMeshFormat()
var listenPort = options.port
var multicastGroup = options.multicastGroup
var selectedService: AudioMeshService?
var codecID = options.codecID ?? .pcmFloat32

if options.discover {
    print("Searching for Audio Mesh sources...")
    let services = AudioMeshServiceBrowser().discover(timeout: options.discoveryTimeout)

    if services.isEmpty {
        print("No Audio Mesh sources found. Falling back to UDP port \(listenPort).")
    } else {
        print("Found Audio Mesh sources:")
        for service in services {
            let groupDescription = service.group.map { " group=\($0)" } ?? ""
            print("- \(service.name) transport=\(service.transport) codec=\(service.codecID.rawValue) port=\(service.port)\(groupDescription)")
        }

        if let selected = services.first {
            selectedService = selected
            listenPort = selected.port
            codecID = options.codecID ?? selected.codecID
            if selected.transport == "multicast" {
                multicastGroup = selected.group
            }
            print("Using source \"\(selected.name)\"")
        }
    }
}

let receiver = try UDPReceiver(
    port: listenPort,
    multicastGroup: multicastGroup,
    receiveTimeout: options.seconds == nil ? nil : 0.25
)

if let selectedService,
   selectedService.transport == "unicast",
   let hostName = selectedService.hostName,
   let controlPort = selectedService.controlPort {
    do {
        try AudioMeshControlClient().requestStart(
            host: hostName,
            controlPort: controlPort,
            audioPort: listenPort
        )
        print("Requested unicast stream from \(selectedService.name) via \(hostName):\(controlPort)")
    } catch {
        print("Could not request unicast stream: \(error)")
    }
}

let audioPlayer = options.playAudio ? try AudioPlayer(meshFormat: meshFormat) : nil
let decoder = AudioMeshCodecFactory.makeDecoder(codecID: codecID)
let expectedEncodedPayloadByteCount = codecID == .pcmFloat32 ? meshFormat.payloadByteCount : nil
var jitterBuffer = JitterBuffer(prebufferPacketCount: options.prebufferPackets)
var sequenceMetrics = PacketSequenceMetrics()
var scheduled = 0
var invalidPackets = 0
let started = Date()

if let multicastGroup {
    print("Audio Mesh receiver listening on UDP port \(listenPort), multicast group \(multicastGroup)")
} else {
    print("Audio Mesh receiver listening on UDP port \(listenPort)")
}
print("Codec: \(codecID.rawValue)")

while true {
    if let seconds = options.seconds, Date().timeIntervalSince(started) >= seconds {
        break
    }

    let data: Data
    do {
        data = try receiver.receive()
    } catch UDPSocketError.receiveTimedOut {
        continue
    }

    do {
        let packet = try AudioMeshPacket.decode(data, expectedPayloadBytes: expectedEncodedPayloadByteCount)
        sequenceMetrics.observe(sequenceNumber: packet.sequenceNumber)
        jitterBuffer.push(packet)

        while let ready = jitterBuffer.popReady() {
            scheduled += 1
            let pcmPayload = try decoder.decode(encodedPayload: ready.payload)
            audioPlayer?.schedule(payload: pcmPayload, meshFormat: meshFormat)
        }

        if sequenceMetrics.receivedPacketCount % options.statsInterval == 0 {
            printStats(
                metrics: sequenceMetrics,
                scheduled: scheduled,
                invalidPackets: invalidPackets,
                jitterBuffer: jitterBuffer,
                started: started
            )
        }
    } catch {
        invalidPackets += 1
        print("dropped packet: \(error)")
    }
}

printStats(
    metrics: sequenceMetrics,
    scheduled: scheduled,
    invalidPackets: invalidPackets,
    jitterBuffer: jitterBuffer,
    started: started
)

private func printStats(
    metrics: PacketSequenceMetrics,
    scheduled: Int,
    invalidPackets: Int,
    jitterBuffer: JitterBuffer,
    started: Date
) {
    let elapsed = Date().timeIntervalSince(started)
    let rate = Double(metrics.receivedPacketCount) / max(elapsed, 0.001)
    print(
        "received=\(metrics.receivedPacketCount) " +
        "scheduled=\(scheduled) " +
        "missing=\(metrics.missingPacketCount) " +
        "reordered_or_duplicate=\(metrics.reorderedOrDuplicatePacketCount) " +
        "invalid=\(invalidPackets) " +
        "skipped=\(jitterBuffer.skippedPacketCount) " +
        "queued=\(jitterBuffer.queuedPacketCount) " +
        "packets_per_second=\(String(format: "%.1f", rate))"
    )
}
