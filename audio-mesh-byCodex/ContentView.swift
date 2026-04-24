//
//  ContentView.swift
//  audio-mesh-byCodex
//
//  Created by Florin Ilie on 24.04.26.
//

import Combine
import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var runner = LocalAudioMeshRunner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Project") {
                        TextField("Project folder", text: $runner.projectPath)
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            Button("Build CLI Tools") {
                                runner.build()
                            }
                            .disabled(runner.isBuilding)

                            Button("Stop All") {
                                runner.stopAll()
                            }
                            .disabled(!runner.hasRunningProcess)
                        }
                    }

                    Section("Real Network Test") {
                        Picker("Codec", selection: $runner.codec) {
                            Text("Opus").tag(AudioMeshCodec.opus)
                            Text("PCM Float32").tag(AudioMeshCodec.pcmFloat32)
                        }
                        .pickerStyle(.segmented)

                        Toggle("Play receiver audio on this Mac", isOn: $runner.playReceiverAudio)

                        HStack {
                            Button {
                                runner.startAdvertisedSource()
                            } label: {
                                Label("Start Source", systemImage: "dot.radiowaves.left.and.right")
                            }
                            .disabled(runner.sourceState == .running)

                            Button {
                                runner.startReceiver()
                            } label: {
                                Label("Start Receiver", systemImage: "speaker.wave.2")
                            }
                            .disabled(runner.receiverState == .running)
                        }
                    }

                    Section("Status") {
                        statusRow("Build", runner.buildState)
                        statusRow("Source", runner.sourceState)
                        statusRow("Receiver", runner.receiverState)
                    }
                }
                .formStyle(.grouped)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Live Log")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            runner.clearLog()
                        }
                    }

                    ScrollView {
                        Text(runner.logText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .frame(minHeight: 240)
            }
            .navigationTitle("Audio Mesh")
        }
    }

    private func statusRow(_ title: String, _ state: LocalProcessState) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(state.title, systemImage: state.systemImage)
                .foregroundStyle(state.color)
        }
    }
}

enum AudioMeshCodec: String, CaseIterable {
    case opus = "opus"
    case pcmFloat32 = "pcm-f32"
}

enum LocalProcessState: Equatable {
    case idle
    case running
    case exited(Int32)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .exited(let code):
            return "Exited \(code)"
        case .failed(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "circle"
        case .running:
            return "play.circle.fill"
        case .exited(let code):
            return code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .running:
            return .blue
        case .exited(let code):
            return code == 0 ? .green : .red
        case .failed:
            return .orange
        }
    }
}

@MainActor
final class LocalAudioMeshRunner: ObservableObject {
    @Published var projectPath = LocalProjectLocator.defaultProjectPath
    @Published var codec = AudioMeshCodec.opus
    @Published var playReceiverAudio = true
    @Published var buildState = LocalProcessState.idle
    @Published var sourceState = LocalProcessState.idle
    @Published var receiverState = LocalProcessState.idle
    @Published private(set) var logText = ""

    private var buildProcess: Process?
    private var sourceProcess: Process?
    private var receiverProcess: Process?

    var isBuilding: Bool {
        buildState == .running
    }

    var hasRunningProcess: Bool {
        buildState == .running || sourceState == .running || receiverState == .running
    }

    func build() {
        buildState = .running
        run(
            name: "build",
            executable: "/usr/bin/swift",
            arguments: ["build"],
            store: { self.buildProcess = $0 },
            updateState: { self.buildState = $0 }
        )
    }

    func startAdvertisedSource() {
        sourceState = .running
        run(
            name: "source",
            executable: cliPath("audiomesh-source"),
            arguments: [
                "--advertise",
                "--name", Host.current().localizedName ?? "Audio Mesh Mac",
                "--port", "5004",
                "--control-port", "5005",
                "--codec", codec.rawValue
            ],
            store: { self.sourceProcess = $0 },
            updateState: { self.sourceState = $0 }
        )
    }

    func startReceiver() {
        var arguments = [
            "--discover",
            "--discovery-timeout", "3",
            "--stats-interval", "20",
            "--codec", codec.rawValue
        ]
        if !playReceiverAudio {
            arguments.append("--no-audio")
        }

        receiverState = .running
        run(
            name: "receiver",
            executable: cliPath("audiomesh-receiver"),
            arguments: arguments,
            store: { self.receiverProcess = $0 },
            updateState: { self.receiverState = $0 }
        )
    }

    func stopAll() {
        [buildProcess, sourceProcess, receiverProcess].forEach { process in
            if process?.isRunning == true {
                process?.terminate()
            }
        }
    }

    func clearLog() {
        logText = ""
    }

    private func cliPath(_ name: String) -> String {
        URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".build/debug/\(name)")
            .path
    }

    private func run(
        name: String,
        executable: String,
        arguments: [String],
        store: @escaping (Process) -> Void,
        updateState: @escaping (LocalProcessState) -> Void
    ) {
        appendLog("$ \(executable) \(arguments.joined(separator: " "))\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.appendLog(text)
            }
        }

        process.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor [weak self] in
                self?.appendLog("[\(name)] exited with code \(process.terminationStatus)\n")
                updateState(.exited(process.terminationStatus))
            }
        }

        do {
            try process.run()
            store(process)
        } catch {
            updateState(.failed(error.localizedDescription))
            appendLog("[\(name)] failed: \(error.localizedDescription)\n")
        }
    }

    private func appendLog(_ text: String) {
        logText.append(text)
        if logText.count > 80_000 {
            logText.removeFirst(logText.count - 80_000)
        }
    }
}

enum LocalProjectLocator {
    static var defaultProjectPath: String {
        let fileManager = FileManager.default
        let candidates = [
            fileManager.currentDirectoryPath,
            NSString(string: "~/Code/codex/audio-mesh-byCodex/audio-mesh-byCodex").expandingTildeInPath
        ]

        return candidates.first { path in
            fileManager.fileExists(atPath: URL(fileURLWithPath: path).appendingPathComponent("Package.swift").path)
        } ?? fileManager.currentDirectoryPath
    }
}

#Preview {
    ContentView()
}
