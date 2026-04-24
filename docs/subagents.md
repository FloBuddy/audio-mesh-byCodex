# Suggested Subagents And Workstreams

These are suggested parallel workstreams. Each subagent should own a clear surface area and avoid rewriting another subagent's code.

## 1. Product And Requirements Agent

Owns:

- Product requirements document.
- MVP acceptance criteria.
- User stories.
- Competitive positioning.
- Pricing assumptions.
- Beta feedback rubric.

Key outputs:

- `docs/prd.md`
- `docs/beta-feedback.md`
- Launch decision checklist.

## 2. macOS Audio Driver Agent

Owns:

- Core Audio virtual output device.
- Audio Server Plug-in / Driver Extension research.
- PCM capture boundary.
- Installer implications.
- Signing/notarization notes.

Key outputs:

- macOS source architecture.
- Prototype virtual device.
- Driver build and install scripts.
- Known OS compatibility matrix.

## 3. Protocol And Streaming Agent

Owns:

- RTP/UDP packet format.
- Opus encoder/decoder integration.
- Jitter buffer.
- Clock/timestamp model.
- Network diagnostics.

Key outputs:

- Shared protocol package.
- Packet schema documentation.
- Latency/dropout test harness.

## 4. Apple Receiver Agent

Owns:

- iOS/iPadOS receiver app.
- tvOS receiver app.
- AVAudioEngine playback.
- Background audio, route changes, interruptions.
- Local Network permission UX.

Key outputs:

- Receiver app prototype.
- Playback state machine.
- App Store entitlement and review notes.

## 5. macOS Source App Agent

Owns:

- Menu bar app.
- Source status UI.
- Receiver list.
- Pairing flow.
- Latency profile settings.
- Diagnostics export.

Key outputs:

- macOS controller app.
- Pairing UX.
- User-facing error model.

## 6. Security And Privacy Agent

Owns:

- Pairing model.
- Threat model.
- Key storage.
- Control-plane authentication.
- Encryption roadmap.

Key outputs:

- `docs/security.md`
- Pairing protocol.
- Privacy policy draft.

## 7. Design And Brand Agent

Owns:

- Product name validation.
- Visual identity.
- App icon direction.
- UI design system.
- Landing page art direction.
- App Store screenshots.

Key outputs:

- Figma/design spec or local design tokens.
- Landing page wireframe.
- App Store creative brief.

## 8. Marketing And Growth Agent

Owns:

- ICP and personas.
- Landing page copy.
- Launch channels.
- Beta recruitment.
- Competitive comparison.
- Pricing tests.

Key outputs:

- Landing page messaging.
- Beta launch plan.
- Outreach list.
- FAQ and objection handling.

## 9. QA And Release Agent

Owns:

- Test matrix.
- Device/router matrix.
- Installer testing.
- Regression checklist.
- Crash/log review process.

Key outputs:

- `docs/test-plan.md`
- Release checklist.
- Known issues template.

## Initial Parallel Split

Start with four agents:

- Agent A: macOS capture/virtual device feasibility.
- Agent B: protocol/Opus/RTP/jitter buffer.
- Agent C: iOS receiver playback/discovery prototype.
- Agent D: product/marketing/design/landing page foundations.

Once the first audio stream plays on iOS, split further into installer, security, tvOS, QA, and launch work.

