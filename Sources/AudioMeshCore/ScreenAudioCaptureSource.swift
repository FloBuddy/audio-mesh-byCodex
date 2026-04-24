import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(macOS 13.0, *)
public final class ScreenAudioCaptureSource: NSObject, SCStreamOutput {
    private let format: AudioMeshFormat
    private let queue = DispatchQueue(label: "AudioMesh.ScreenAudioCaptureSource.queue")
    private let condition = NSCondition()
    private var stream: SCStream?
    private var interleavedSamples: [Float32] = []
    private var isStopped = false

    public init(format: AudioMeshFormat = AudioMeshFormat()) {
        self.format = format
        super.init()
    }

    public func start() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw ScreenAudioCaptureError.noDisplay
        }

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = format.sampleRate
        configuration.channelCount = format.channels
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    public func stop() async {
        markStopped()

        if let stream {
            try? await stream.stopCapture()
        }
    }

    private func markStopped() {
        isStopped = true
        condition.lock()
        condition.broadcast()
        condition.unlock()
    }

    public func nextPayload() -> Data? {
        let neededSamples = format.framesPerPacket * format.channels

        condition.lock()
        while interleavedSamples.count < neededSamples && !isStopped {
            condition.wait()
        }

        guard interleavedSamples.count >= neededSamples else {
            condition.unlock()
            return nil
        }

        let packetSamples = Array(interleavedSamples.prefix(neededSamples))
        interleavedSamples.removeFirst(neededSamples)
        condition.unlock()

        return packetSamples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio, sampleBuffer.isValid else {
            return
        }

        appendSamples(from: sampleBuffer)
    }

    private func appendSamples(from sampleBuffer: CMSampleBuffer) {
        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                  let sourceFormat = AVAudioFormat(
                    standardFormatWithSampleRate: description.mSampleRate,
                    channels: description.mChannelsPerFrame
                  ),
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: sourceFormat,
                    bufferListNoCopy: audioBufferList.unsafePointer
                  ),
                  let channelData = buffer.floatChannelData else {
                return
            }

            let sourceChannels = Int(buffer.format.channelCount)
            let frames = Int(buffer.frameLength)
            var appended: [Float32] = []
            appended.reserveCapacity(frames * format.channels)

            for frame in 0..<frames {
                for channel in 0..<format.channels {
                    let sourceChannel = min(channel, max(sourceChannels - 1, 0))
                    appended.append(channelData[sourceChannel][frame])
                }
            }

            condition.lock()
            interleavedSamples.append(contentsOf: appended)
            condition.signal()
            condition.unlock()
        }
    }
}

public enum ScreenAudioCaptureError: Error {
    case noDisplay
}
