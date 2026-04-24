//
//  ContentView.swift
//  audio-mesh-byCodex
//
//  Created by Florin Ilie on 24.04.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Prototype Status") {
                    Label("SwiftPM core merged into this Xcode project folder", systemImage: "checkmark.circle.fill")
                    Label("UDP packet stream and jitter buffer implemented", systemImage: "network")
                    Label("Receiver diagnostics include RTP jitter", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Receiver playback uses AVAudioEngine on macOS", systemImage: "speaker.wave.2.fill")
                }

                Section("Local Test") {
                    commandBlock("swift build")
                    commandBlock(".build/debug/audiomesh-receiver --port 5004")
                    commandBlock(".build/debug/audiomesh-source --host 127.0.0.1 --port 5004 --seconds 10")
                }

                Section("Discovery Test") {
                    commandBlock(".build/debug/audiomesh-source --advertise --name \"Studio Mac\" --port 5004 --control-port 5005")
                    commandBlock(".build/debug/audiomesh-receiver --discover --discovery-timeout 3 --no-audio --seconds 10 --stats-interval 50 --codec pcm-f32")
                }

                Section("System Audio Capture") {
                    commandBlock(".build/debug/audiomesh-source --advertise --name \"Studio Mac\" --port 5004 --control-port 5005 --screen-audio")
                    commandBlock(".build/debug/audiomesh-receiver --discover")
                }

                Section("Opus Test") {
                    commandBlock(".build/debug/audiomesh-source --advertise --name \"Studio Mac\" --port 5004 --control-port 5005 --codec opus")
                    commandBlock(".build/debug/audiomesh-receiver --discover --codec opus")
                }

                Section("No-Audio Smoke Test") {
                    commandBlock(".build/debug/audiomesh-receiver --no-audio --port 5004")
                }

                Section("Next Implementation Steps") {
                    Label("Latency and buffer-depth metrics", systemImage: "chart.line.uptrend.xyaxis")
                    Label("iOS receiver target", systemImage: "iphone")
                    Label("Virtual output device spike", systemImage: "speaker.wave.3")
                    Label("Packaging for libopus dependency", systemImage: "shippingbox")
                }
            }
            .navigationTitle("Audio Mesh")
        }
    }

    private func commandBlock(_ command: String) -> some View {
        Text(command)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
