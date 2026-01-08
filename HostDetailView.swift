import SwiftUI

struct HostDetailView: View {
    @EnvironmentObject private var scanner: NetworkScanner

    @State private var host: Host
    @State private var isScanningPorts = false

    init(host: Host) {
        _host = State(initialValue: host)
    }

    var body: some View {
        Form {
            Section("Host") {
                LabeledContent("IP Address", value: host.ipAddress)
                if let name = host.hostname ?? host.displayName {
                    LabeledContent("Name", value: name)
                }
                LabeledContent("Status", value: host.isOnline ? "Online" : "Offline")
                if let ms = host.latencyMs {
                    LabeledContent("Latency", value: String(format: "%.0f ms", ms))
                }
                LabeledContent("Type", value: host.deviceType)
                LabeledContent("Last Seen", value: host.lastSeen.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Ports") {
                if isScanningPorts {
                    HStack {
                        ProgressView()
                        Text("Scanning ports…")
                    }
                } else if host.openPorts.isEmpty {
                    Text("No ports scanned yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(host.openPorts.map(String.init).joined(separator: ", "))
                        Text("Common services: \(commonServices(for: host.openPorts))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Scan ports") {
                    Task { await runPortScan() }
                }
                .disabled(isScanningPorts)
            }

            Section("Labels") {
                TextField("Display name", text: Binding(
                    get: { host.displayName ?? "" },
                    set: { host.displayName = $0.isEmpty ? nil : $0 }
                ))
                TextField("Notes", text: Binding(
                    get: { host.notes ?? "" },
                    set: { host.notes = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Actions") {
                Button {
                    UIPasteboard.general.string = host.ipAddress
                } label: {
                    Label("Copy IP", systemImage: "doc.on.doc")
                }
                if let name = host.hostname {
                    Button {
                        UIPasteboard.general.string = name
                    } label: {
                        Label("Copy Hostname", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .navigationTitle(host.displayName ?? host.hostname ?? host.ipAddress)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if host.openPorts.isEmpty {
                await runPortScan()
            }
        }
        .onReceive(scanner.$hosts) { updated in
            if let match = updated.first(where: { $0.id == host.id }) {
                host = match
            }
        }
    }

    private func runPortScan() async {
        isScanningPorts = true
        await scanner.refreshHost(host)
        if let updated = scanner.hosts.first(where: { $0.id == host.id }) {
            host = updated
        }
        isScanningPorts = false
    }

    private func commonServices(for ports: [UInt16]) -> String {
        ports.compactMap { CommonPortNames[$0] }.joined(separator: ", ")
    }
}
