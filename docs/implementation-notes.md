# Implementation Notes

## Current State

The repo now contains a runnable Swift Package prototype. It does not yet install a virtual audio driver. It validates the first shared layer:

- Audio format: 48 kHz, stereo, Float32 PCM.
- Packetization: RTP-style 12-byte header with dynamic payload type `96`.
- Codec boundary: `AudioMeshEncoder` and `AudioMeshDecoder`, with `pcm-f32` passthrough and `opus` implemented.
- Transport: UDP unicast.
- Discovery: Bonjour/mDNS service advertising and discovery using `_audiomesh._udp.`.
- Control: tiny TCP `START <udp-port>` request so a receiver can ask a discovered source to stream back by unicast.
- Source: generated sine wave test tone or ScreenCaptureKit system-audio capture.
- Receiver: UDP receive loop, jitter buffer, AVAudioEngine playback.
- Diagnostics: packet sequence metrics, invalid packet count, jitter skip count, queue depth, buffered audio duration, RTP interarrival jitter, and packet rate.
- macOS control panel: local Xcode app that builds the CLI tools, launches tone or system-audio source and receiver processes, and streams their logs for real LAN testing.

## Why Start Here

The virtual audio driver is the riskiest native component, but it should not be the first place to debug packet timing, receiver scheduling, transport behavior, or audio playback. This prototype lets those parts move independently and gives every future platform a concrete protocol target.

## Commands

Build:

```sh
brew install opus
swift build
```

Test:

```sh
swift test
```

Build the macOS control panel:

```sh
xcodebuild -project audio-mesh-byCodex.xcodeproj -scheme audio-mesh-byCodex -destination platform=macOS build
```

For real MVP testing, run the app from Xcode, press `Build CLI Tools`, then start an advertised tone or system-audio source on one Mac and a discovering receiver on another Mac. The app is intentionally unsandboxed during this phase so it can launch the local SwiftPM executables from `.build/debug`.

Run receiver:

```sh
.build/debug/audiomesh-receiver --port 5004
```

Run source:

```sh
.build/debug/audiomesh-source --host 127.0.0.1 --port 5004 --seconds 10
```

Run receiver without playback:

```sh
.build/debug/audiomesh-receiver --no-audio --port 5004 --seconds 10 --stats-interval 50
```

Advertise source:

```sh
.build/debug/audiomesh-source --advertise --name "Studio Mac" --port 5004 --control-port 5005
```

Discover sources:

```sh
.build/debug/audiomesh-receiver --discover --discovery-timeout 3 --no-audio
```

Print stream diagnostics more often:

```sh
.build/debug/audiomesh-receiver --discover --no-audio --seconds 10 --stats-interval 50 --codec pcm-f32
```

Use Opus:

```sh
.build/debug/audiomesh-source --advertise --name "Studio Mac" --port 5004 --control-port 5005 --codec opus
.build/debug/audiomesh-receiver --discover --codec opus
```

Capture macOS system audio:

```sh
.build/debug/audiomesh-source --advertise --name "Studio Mac" --port 5004 --control-port 5005 --screen-audio
.build/debug/audiomesh-receiver --discover
```

The `--screen-audio` mode uses ScreenCaptureKit and may require Screen Recording permission for Terminal, Xcode, or the launching host process. It is a prototype capture path, not the final virtual output device.

Experimental multicast discovery and receive:

```sh
.build/debug/audiomesh-source --multicast --name "Studio Mac"
.build/debug/audiomesh-receiver --discover
```

Bonjour discovery and receiver-requested unicast have been verified locally. Multicast packet delivery did not complete in the local sandbox, so multicast remains experimental.

## Near-Term Engineering Steps

1. Add end-to-end latency measurement.
2. Add an iOS receiver target that reuses the same protocol types.
3. Start the macOS virtual output device spike.
4. Add packaging notes for the Homebrew/system `libopus` dependency.
