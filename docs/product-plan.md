# Audio Mesh Product Plan

## One-Line Product

Audio Mesh is a cross-platform local audio mesh that lets many kinds of devices act as audio sources and receivers on the same LAN. The first implementation turns a Mac into a local network audio source and lets nearby Apple devices receive that stream through their own speakers or paired headphones.

## MVP Positioning

The product vision is cross-platform device unification. The first version should focus on Apple devices only because those are the devices available for development and testing:

- Source: macOS app plus virtual output device named `Audio Mesh`.
- Receivers: iPhone, iPad, Apple TV, and macOS receiver.
- Later receiver: Apple Watch, only after validating watchOS networking, background playback, battery behavior, and App Store constraints.
- Not supported for MVP: iPhone or iPad as a system-wide source. iOS does not expose general third-party system audio capture; Apple APIs support app audio, microphone audio, and specific capture flows, not arbitrary global audio routing.

This is an implementation sequence, not a market-positioning limit. The protocol, branding, documentation, and architecture should assume Windows, Linux, Android, embedded receivers, smart TVs, and other devices will join the mesh later.

The sharp initial use case is:

> I am listening on my Mac. I move rooms. I open Audio Mesh on the nearby Apple device, select the Mac stream, and hear the same audio through that device or its paired headphones.

## Product Principles

- Manual selection first. Do not solve automatic roaming or Bluetooth handoff in the MVP.
- LAN-only first. Avoid cloud accounts, remote access, relays, and privacy concerns until the local product is excellent.
- Cross-platform protocol first. Apple-specific UI and driver code should sit at the edge, not define the system.
- Reliability beats ultra-low latency. Target podcasts, long-form video, music, and passive listening before games or calls.
- Use boring protocols. Prefer mDNS/Bonjour, RTP, UDP, Opus, and explicit buffering over a custom transport.
- Be honest in UX. Show expected latency, connected receiver count, network quality, and whether the stream is private to the LAN.

## MVP Features

### macOS Source

- Installs a virtual Core Audio output device named `Audio Mesh`.
- Captures 2-channel PCM at 48 kHz.
- Encodes to Opus.
- Advertises the stream on Bonjour as `_audiomesh._tcp.local`.
- Sends audio over LAN using RTP/UDP with Opus payloads.
- Provides a menu bar controller for start/stop, stream name, latency profile, receiver list, and diagnostics.
- Supports three latency profiles:
  - `Low`: 100-200 ms, best-effort Wi-Fi.
  - `Balanced`: 250-500 ms, default.
  - `Stable`: 750-1500 ms, poor Wi-Fi or Apple TV playback.
- Includes a signed installer and uninstaller.

### iOS/iPadOS Receiver

- Discovers Audio Mesh streams on the local network.
- Shows source name, device name, signal status, and latency mode.
- Plays decoded audio using AVAudioEngine/AVAudioPlayerNode.
- Supports AirPods or any currently selected iOS audio route.
- Handles interruptions, route changes, lock screen playback controls, and background audio.
- Requests Local Network permission clearly and only when needed.

### tvOS Receiver

- Same discovery and playback model as iOS.
- Optimized for fixed room playback through Apple TV speakers, HDMI receivers, or paired Bluetooth headphones.
- Simple remote-first UI: discovered streams, connect/disconnect, buffer mode.

### macOS Receiver

- Useful for testing and for multi-Mac households.
- Also serves as the first desktop diagnostic client.

## Deferred Features

- Automatic nearest-device handoff.
- Bluetooth pairing automation.
- iOS/iPadOS system-wide source.
- Internet streaming outside the LAN.
- Multi-source mixing.
- Studio-grade sync between many rooms.
- Windows, Android, Linux sources and receivers. These are deferred from the first implementation, not outside the product vision.
- Video delay integration.
- End-to-end encryption beyond LAN pairing.

## Technical Architecture

### Source Pipeline

1. Core Audio virtual output device receives PCM.
2. Source daemon/app reads PCM frames.
3. Audio is normalized to 48 kHz stereo float or int16 depending on encoder boundary.
4. Opus encoder emits 20 ms frames by default.
5. RTP packetizer adds sequence number and timestamp.
6. Stream service advertises metadata through Bonjour.
7. UDP sender transmits to subscribed receiver endpoints.

### Receiver Pipeline

1. Bonjour browser discovers sources.
2. User selects a source.
3. Receiver opens control connection to request stream parameters.
4. Receiver joins unicast UDP stream for MVP.
5. Jitter buffer reorders and delays packets.
6. Opus decoder outputs PCM.
7. AVAudioEngine schedules buffers to local output.
8. Receiver monitors drift and adjusts buffer depth.

### Protocol Choice

Use RTP over UDP with Opus for the audio plane. Use TCP or QUIC later for control if needed, but keep MVP control simple:

- Discovery: Bonjour/mDNS.
- Control: small HTTP or TCP JSON endpoint on the source.
- Audio: RTP/UDP Opus.

Default to unicast for MVP. Multicast can come later once the product needs many simultaneous receivers and the team has tested router compatibility.

## Apple Implementation Notes

### macOS Source Device

The commercial-safe path is to implement a Core Audio Audio Server Plug-in / Driver Extension using Apple’s sample architecture. BlackHole can be studied as prior art, but its current public licensing is GPL-3.0 and its README says non-GPL projects need a license.

Alternative prototype path:

- Build a temporary app using Core Audio process/system audio taps where supported.
- This validates capture, encode, stream, and receiver UX quickly.
- It does not fully satisfy the final promise of appearing as a normal output device.

### iOS/watchOS Limits

iOS and iPadOS receiver apps are viable. iOS/iPadOS source apps are not part of the MVP because third-party apps cannot generally capture all system output.

Apple Watch should be treated as a research milestone, not an MVP dependency. It may be excellent for the roaming use case, but it has tighter constraints around networking, battery, audio sessions, background behavior, and Bluetooth route behavior.

## Security And Privacy

MVP should not broadcast raw access to every LAN device without user intent.

Recommended MVP security:

- LAN-only by default.
- Pair receiver with source using a short code or QR code.
- Generate per-source shared secret after pairing.
- Sign control messages.
- Optional SRTP or encrypted audio after initial validation.
- Prominent menu bar indicator when streaming.
- No audio recording to disk by default.

## Success Metrics

- Time from install to first audio on iPhone: under 3 minutes.
- Time from opening receiver app to hearing audio: under 5 seconds after first pairing.
- Balanced mode dropout rate: under 1 audible dropout per 30 minutes on normal home Wi-Fi.
- CPU on source: under 8% on Apple Silicon MacBook Air during stereo streaming.
- Receiver battery drain: acceptable for 1-2 hour listening sessions.
- App Store review passes for receiver apps.
- Installer support burden is manageable.

## Main Risks

- macOS virtual audio driver signing, installation, and support complexity.
- App Store review and background audio behavior for iOS/watchOS receivers.
- Wi-Fi variability causing dropouts.
- Latency disappointment for video users.
- Licensing risk if reusing GPL driver code.
- Users expecting AirPlay-like polish before the underlying reliability is ready.
