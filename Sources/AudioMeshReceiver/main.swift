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
        case "--help", "-h":
            print("""
            Usage: audiomesh-receiver [--port 5004] [--prebuffer 8] [--no-audio]
                                      [--discover] [--discovery-timeout 3] [--group 239.255.42.99]

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

if options.discover {
    print("Searching for Audio Mesh sources...")
    let services = AudioMeshServiceBrowser().discover(timeout: options.discoveryTimeout)

    if services.isEmpty {
        print("No Audio Mesh sources found. Falling back to UDP port \(listenPort).")
    } else {
        print("Found Audio Mesh sources:")
        for service in services {
            let groupDescription = service.group.map { " group=\($0)" } ?? ""
            print("- \(service.name) transport=\(service.transport) port=\(service.port)\(groupDescription)")
        }

        if let selected = services.first {
            listenPort = selected.port
            if selected.transport == "multicast" {
                multicastGroup = selected.group
            }
            print("Using source \"\(selected.name)\"")
        }
    }
}

let receiver = try UDPReceiver(port: listenPort, multicastGroup: multicastGroup)
let audioPlayer = options.playAudio ? try AudioPlayer(meshFormat: meshFormat) : nil
var jitterBuffer = JitterBuffer(prebufferPacketCount: options.prebufferPackets)
var received = 0
var scheduled = 0
let started = Date()

if let multicastGroup {
    print("Audio Mesh receiver listening on UDP port \(listenPort), multicast group \(multicastGroup)")
} else {
    print("Audio Mesh receiver listening on UDP port \(listenPort)")
}

while true {
    let data = try receiver.receive()

    do {
        let packet = try AudioMeshPacket.decode(data, expectedPayloadBytes: meshFormat.payloadByteCount)
        received += 1
        jitterBuffer.push(packet)

        while let ready = jitterBuffer.popReady() {
            scheduled += 1
            audioPlayer?.schedule(payload: ready.payload, meshFormat: meshFormat)
        }

        if received % 100 == 0 {
            let elapsed = Date().timeIntervalSince(started)
            let rate = Double(received) / max(elapsed, 0.001)
            print("received=\(received) scheduled=\(scheduled) packets_per_second=\(String(format: "%.1f", rate))")
        }
    } catch {
        print("dropped packet: \(error)")
    }
}
