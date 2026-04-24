# Audio Mesh Roadmap

## Phase 0: Validation Prototype

Goal: prove the end-to-end audio path before investing deeply in driver UX.

Deliverables:

- macOS command-line source that captures from a temporary audio input/tap or test tone.
- Shared protocol library for RTP/UDP Opus packets.
- macOS receiver CLI or simple app.
- iOS receiver prototype.
- Bonjour discovery proof.
- Latency, jitter, dropout, and CPU instrumentation.

Exit criteria:

- iPhone discovers a Mac stream on the LAN.
- iPhone plays stable audio for 30 minutes.
- Balanced latency lands under 500 ms.
- Reconnect works after receiver app background/foreground transitions.

## Phase 1: Apple MVP

Goal: deliver the first usable product on available Apple hardware while preserving the cross-platform architecture.

Deliverables:

- macOS virtual output device named `Audio Mesh`.
- macOS menu bar controller.
- Signed macOS installer and uninstaller.
- iOS/iPadOS receiver app.
- tvOS receiver app if iOS receiver foundation is stable.
- Pairing model.
- Basic encrypted control plane.
- Diagnostics screen and log export.
- Public landing page and private beta signup.

Exit criteria:

- Fresh user can install and stream from Mac to iPhone without developer tools.
- Audio survives Wi-Fi hiccups with clear UI feedback.
- No major crashers across supported Apple OS versions.
- Beta users understand the product’s current latency limitations.

## Phase 2: Watch And Polish

Goal: validate the highest-value roaming receiver and make the product feel native.

Deliverables:

- watchOS receiver feasibility prototype.
- Route-change handling improvements for AirPods and Bluetooth headphones.
- Better receiver handoff UX: pause on one receiver, resume on another.
- Improved latency estimator.
- Onboarding refinements.
- App Store launch assets.

Exit criteria:

- Clear decision on whether Apple Watch is launch, beta, or deferred.
- Receiver reconnect flow is fast enough for room-to-room movement.
- Support docs cover the common network and Bluetooth problems.

## Phase 3: Cross-Platform Expansion

Goal: add non-Apple platforms after the protocol, receiver model, and source UX are proven.

Deliverables:

- Android receiver.
- Windows source research.
- Linux source/receiver using PipeWire where possible.
- Android source only if capture constraints and permissions match product expectations.
- Multi-receiver improvements.
- Optional multicast mode.

Exit criteria:

- Non-Apple receivers interoperate with Apple source.
- Protocol is stable enough to document publicly.
- Expansion validates that the core protocol is truly cross-platform rather than Apple-specific.

## Phase 4: Premium Features

Goal: create durable differentiation and monetization.

Deliverables:

- Multi-room synchronized playback.
- Video sync assistant or per-app delay guidance.
- Advanced diagnostics.
- Family sharing / household device management.
- Optional high-quality mode.
- Optional developer protocol docs.

## Development Milestones

### Week 1-2

- Create repo structure.
- Decide language split: Swift for Apple apps, C/C++ or Rust for protocol/codec core.
- Build Opus encode/decode loop.
- Build RTP packetizer and jitter buffer.
- Build Bonjour advertise/discover.

### Week 3-4

- Prototype macOS source with test tone and then real captured audio.
- Prototype iOS receiver playback.
- Measure latency and dropout behavior.
- Decide unicast-only MVP details.

### Week 5-8

- Start macOS virtual output device.
- Build menu bar app.
- Build iOS receiver app UI.
- Add pairing and receiver authorization.
- Add logs and diagnostics.

### Week 9-12

- Installer, signing, notarization.
- tvOS receiver.
- Beta onboarding and landing page.
- Internal dogfood across multiple routers and available Apple devices.

### Week 13-16

- Private beta.
- Fix installer failures, background audio issues, route changes, and network edge cases.
- Prepare launch content.
- Decide watchOS state.

## MVP Cut Line

Ship the MVP only if these are true:

- Mac source appears as a normal output device.
- iPhone receiver is stable enough for podcasts/music.
- Setup does not require Terminal.
- Uninstall is clean.
- Latency is explained honestly.
- The product does not imply iPhone can be a system-wide source.
