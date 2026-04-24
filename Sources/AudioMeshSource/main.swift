import AudioMeshCore
import Foundation

struct SourceOptions {
    var host = "127.0.0.1"
    var port: UInt16 = 5004
    var frequency = 440.0
    var seconds: Double?
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
        case "--frequency":
            if let value = iterator.next(), let frequency = Double(value) {
                options.frequency = frequency
            }
        case "--seconds":
            if let value = iterator.next(), let seconds = Double(value) {
                options.seconds = seconds
            }
        case "--help", "-h":
            print("""
            Usage: audiomesh-source [--host 127.0.0.1] [--port 5004] [--frequency 440] [--seconds 10]

            Sends a 48 kHz stereo Float32 test tone using Audio Mesh RTP-style UDP packets.
            """)
            exit(0)
        default:
            break
        }
    }

    return options
}

let options = parseOptions()
let format = AudioMeshFormat()
let sender = try UDPSender(host: options.host, port: options.port)
var tone = SineWaveSource(format: format, frequency: options.frequency)
let ssrc = UInt32.random(in: 1...UInt32.max)
let started = Date()
var sequenceNumber: UInt16 = 0
var timestamp: UInt32 = 0

print("Audio Mesh source sending \(options.frequency) Hz tone to \(options.host):\(options.port)")

while true {
    if let seconds = options.seconds, Date().timeIntervalSince(started) >= seconds {
        break
    }

    let payload = tone.nextPayload()
    let packet = AudioMeshPacket(
        sequenceNumber: sequenceNumber,
        timestamp: timestamp,
        ssrc: ssrc,
        payload: payload
    )

    try sender.send(packet.encode())
    sequenceNumber &+= 1
    timestamp &+= UInt32(format.framesPerPacket)
    Thread.sleep(forTimeInterval: format.packetDurationSeconds)
}

print("Audio Mesh source stopped")

