# Implementation Notes

## Current State

The repo now contains a runnable Swift Package prototype. It does not yet capture system audio or install a virtual audio driver. It validates the first shared layer:

- Audio format: 48 kHz, stereo, Float32 PCM.
- Packetization: RTP-style 12-byte header with dynamic payload type `96`.
- Transport: UDP unicast.
- Discovery: Bonjour/mDNS service advertising and discovery using `_audiomesh._udp.`.
- Source: generated sine wave test tone.
- Receiver: UDP receive loop, jitter buffer, AVAudioEngine playback.

## Why Start Here

The virtual audio driver is the riskiest native component, but it should not be the first place to debug packet timing, receiver scheduling, transport behavior, or audio playback. This prototype lets those parts move independently and gives every future platform a concrete protocol target.

## Commands

Build:

```sh
swift build
```

Test:

```sh
swift test
```

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
.build/debug/audiomesh-receiver --no-audio --port 5004
```

Advertise source:

```sh
.build/debug/audiomesh-source --advertise --name "Studio Mac" --host 127.0.0.1 --port 5004
```

Discover sources:

```sh
.build/debug/audiomesh-receiver --discover --discovery-timeout 3 --no-audio
```

Experimental multicast discovery and receive:

```sh
.build/debug/audiomesh-source --multicast --name "Studio Mac"
.build/debug/audiomesh-receiver --discover
```

Bonjour discovery has been verified locally. Multicast packet delivery did not complete in the local sandbox, so the next practical step is a source control endpoint that lets a discovered receiver request unicast streaming to its own IP/port.

## Near-Term Engineering Steps

1. Add a simple control endpoint so receivers can request unicast streaming after discovery.
2. Replace test tone source with macOS audio capture prototype.
3. Add Opus encode/decode behind a codec abstraction.
4. Add packet loss, jitter, and latency metrics.
5. Add an iOS receiver target that reuses the same protocol types.
6. Start the macOS virtual output device spike.
