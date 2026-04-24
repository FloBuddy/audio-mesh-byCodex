# Audio Mesh

Audio Mesh is a cross-platform network audio layer for connecting the devices you already own. The long-term goal is to make Macs, PCs, Linux boxes, phones, tablets, TVs, watches, speakers, and headphones work together as one local audio mesh.

The first MVP starts with Apple products because they are the devices available for development and testing: a Mac source with a virtual audio output named `Audio Mesh`, plus iPhone, iPad, Apple TV, and Mac receivers.

## Planning Documents

- [Product plan](docs/product-plan.md)
- [Roadmap](docs/roadmap.md)
- [Subagents and workstreams](docs/subagents.md)
- [Marketing and landing page plan](docs/marketing-and-landing.md)
- [Implementation notes](docs/implementation-notes.md)

## Current Prototype

The first implementation is a Swift Package with:

- `AudioMeshCore`: packet format, 48 kHz stereo audio format, UDP transport, sine test source, and jitter buffer.
- Bonjour/mDNS service advertising and discovery for `_audiomesh._udp.` streams.
- `audiomesh-source`: sends a test tone as RTP-style UDP packets.
- `audiomesh-receiver`: receives packets, jitter-buffers them, and plays audio with AVAudioEngine.

Build and test:

```sh
swift build
swift test
```

Run a local loopback smoke test:

```sh
.build/debug/audiomesh-receiver --port 5004
.build/debug/audiomesh-source --host 127.0.0.1 --port 5004 --seconds 10
```

For packet/transport testing without speaker output:

```sh
.build/debug/audiomesh-receiver --no-audio --port 5004
```

Advertise and discover a stream:

```sh
.build/debug/audiomesh-source --advertise --name "Studio Mac" --host 127.0.0.1 --port 5004
.build/debug/audiomesh-receiver --discover --discovery-timeout 3 --no-audio
```

Experimental multicast mode:

```sh
.build/debug/audiomesh-source --multicast --name "Studio Mac"
.build/debug/audiomesh-receiver --discover
```

Bonjour discovery is working. Multicast packet delivery still needs more real-network testing; unicast remains the reliable audio path for local development.

## MVP Focus

- Cross-platform protocol and architecture from day one.
- macOS source with a real virtual output device.
- iOS/iPadOS receiver.
- macOS receiver for testing and multi-Mac homes.
- tvOS receiver if the shared receiver core is stable.
- watchOS research after the core product works.

The MVP intentionally avoids automatic Bluetooth handoff, indoor location, internet streaming, and iOS/iPadOS as a system-wide audio source. Windows, Linux, Android, and other device classes remain part of the core product vision, not a separate product.
