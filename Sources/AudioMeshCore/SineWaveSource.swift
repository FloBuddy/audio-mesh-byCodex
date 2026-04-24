import Foundation

public struct SineWaveSource {
    private let format: AudioMeshFormat
    private let frequency: Double
    private var phase: Double = 0

    public init(format: AudioMeshFormat = AudioMeshFormat(), frequency: Double = 440) {
        self.format = format
        self.frequency = frequency
    }

    public mutating func nextPayload(amplitude: Float = 0.25) -> Data {
        var samples = [Float32]()
        samples.reserveCapacity(format.framesPerPacket * format.channels)

        let phaseStep = 2.0 * Double.pi * frequency / Double(format.sampleRate)
        for _ in 0..<format.framesPerPacket {
            let sample = Float32(sin(phase)) * amplitude
            phase += phaseStep
            if phase > 2.0 * Double.pi {
                phase -= 2.0 * Double.pi
            }

            for _ in 0..<format.channels {
                samples.append(sample)
            }
        }

        return samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}

