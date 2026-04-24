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
                    Label("Receiver playback uses AVAudioEngine on macOS", systemImage: "speaker.wave.2.fill")
                }

                Section("Local Test") {
                    commandBlock("swift build")
                    commandBlock(".build/debug/audiomesh-receiver --port 5004")
                    commandBlock(".build/debug/audiomesh-source --host 127.0.0.1 --port 5004 --seconds 10")
                }

                Section("Discovery Test") {
                    commandBlock(".build/debug/audiomesh-source --advertise --name \"Studio Mac\" --host 127.0.0.1 --port 5004")
                    commandBlock(".build/debug/audiomesh-receiver --discover --discovery-timeout 3 --no-audio")
                }

                Section("No-Audio Smoke Test") {
                    commandBlock(".build/debug/audiomesh-receiver --no-audio --port 5004")
                }

                Section("Next Implementation Steps") {
                    Label("Receiver-to-source unicast control", systemImage: "arrow.left.arrow.right")
                    Label("macOS audio capture prototype", systemImage: "waveform")
                    Label("Opus codec integration", systemImage: "slider.horizontal.3")
                    Label("iOS receiver target", systemImage: "iphone")
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
