import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var scanner: NetworkScanner

    @State private var sortMode: SortMode = .ipAscending
    @State private var filterText: String = ""
    @State private var expanded: Set<Host.ID> = []
    @State private var quickRoleFilter: Set<Host.Role> = []
    @State private var exportFormat: ExportFormat = .json

    enum SortMode: String, CaseIterable, Identifiable {
        case ipAscending = "IP"
        case nameAscending = "Name"
        case portsDescending = "Ports"
        var id: String { rawValue }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        var id: String { rawValue }
    }

    private var filteredHosts: [Host] {
        var hosts = scanner.hosts
        if !filterText.isEmpty {
            let f = filterText.lowercased()
            hosts = hosts.filter {
                $0.ipAddress.lowercased().contains(f) ||
                ($0.hostname?.lowercased().contains(f) ?? false) ||
                ($0.displayName?.lowercased().contains(f) ?? false) ||
                $0.deviceType.lowercased().contains(f)
            }
        }
        if !quickRoleFilter.isEmpty {
            hosts = hosts.filter { quickRoleFilter.contains($0.role) }
        }
        return hosts
    }

    private var sortedHosts: [Host] {
        var hosts = filteredHosts
        switch sortMode {
        case .ipAscending:
            hosts.sort { ipToSortable($0.ipAddress) < ipToSortable($1.ipAddress) }
        case .nameAscending:
            hosts.sort { ($0.displayName ?? $0.hostname ?? $0.ipAddress) < ($1.displayName ?? $1.hostname ?? $1.ipAddress) }
        case .portsDescending:
            hosts.sort { $0.openPorts.count > $1.openPorts.count }
        }
        return hosts
    }

    private var hostsByRole: [(Host.Role, [Host])] {
        Host.Role.allCases.map { role in
            (role, sortedHosts.filter { $0.role == role })
        }
        .filter { !$0.1.isEmpty }
    }

    private var portHistogram: [(port: UInt16, count: Int)] {
        var counts: [UInt16: Int] = [:]
        for h in scanner.hosts {
            for p in h.openPorts {
                counts[p, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    private var servicesSummary: String {
        portHistogram.map { p in
            (CommonPortNames[p.port] ?? "\(p.port)") + "(\(p.count))"
        }.joined(separator: "  ")
    }

    var body: some View {
        ZStack {
            NetworkBackground()

            ScrollView {
                VStack(spacing: 12) {
                    header
                    summaryCards
                    roleFilterChips
                    topologyMiniMap
                    exportBar
                    hostSections
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
        .ignoresSafeArea(edges: .horizontal)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Label("Network Scan", systemImage: "wave.3.right")
                    .labelStyle(.titleAndIcon)
                    .font(.title3.weight(.semibold))

                Spacer()

                Menu {
                    Picker("Profile", selection: $scanner.selectedProfile) {
                        ForEach(NetworkScanner.ScanProfile.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                } label: {
                    Label(scanner.selectedProfile.rawValue, systemImage: "slider.horizontal.3")
                }
                .menuStyle(.automatic)

                if scanner.isScanning {
                    Button {
                        scanner.cancelScan()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }

                Button {
                    scanner.scan()
                } label: {
                    HStack(spacing: 6) {
                        if scanner.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(scanner.isScanning ? "Scanning" : "Scan")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(scanner.isScanning)
            }

            HStack(spacing: 8) {
                TextField("Filter by IP, name, type…", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)

                Picker("Sort", selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: 220)
            }

            HStack(spacing: 8) {
                Label(scanner.activeSubnetDescription, systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if scanner.isScanning {
                    HStack(spacing: 10) {
                        ProgressView(value: scanner.progress.fractionCompleted)
                            .progressViewStyle(.linear)
                        Text(scanner.progress.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.top, 12)
    }

    private var roleFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Host.Role.allCases) { role in
                    let active = quickRoleFilter.contains(role)
                    Button {
                        if active { quickRoleFilter.remove(role) } else { quickRoleFilter.insert(role) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: role.symbol)
                            Text(role.rawValue)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(active ? role.color.opacity(0.25) : Color.white.opacity(0.06))
                        .foregroundStyle(active ? .white : .secondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var summaryCards: some View {
        let total = scanner.hosts.count
        let online = scanner.hosts.filter { $0.isOnline }.count
        let pct = total > 0 ? Int((Double(online) / Double(total)) * 100) : 0
        let avgLatency = scanner.hosts.compactMap { $0.latencyMs }.average

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatCard(title: "Devices", value: "\(total)", caption: "Online: \(online) (\(pct)%)", color: .green)
                StatCard(title: "Top Services", value: portHistogram.prefix(3).map { CommonPortNames[$0.port] ?? "\($0.port)" }.joined(separator: " • "), caption: servicesSummary, color: .blue)
            }
            HStack(spacing: 8) {
                StatCard(title: "Avg Latency", value: avgLatency.map { String(format: "%.0f ms", $0) } ?? "—", caption: "Min TCP connect", color: .teal)
                StatCard(title: "Ports Scanned", value: "\(scanner.selectedProfile.ports.count)", caption: scanner.selectedProfile.rawValue, color: .purple)
            }
        }
    }

    private var topologyMiniMap: some View {
        TopologyView(hosts: scanner.hosts)
            .frame(height: 180)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var exportBar: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
            } label: {
                Label(exportFormat.rawValue, systemImage: "square.and.arrow.up")
            }

            if let data = exportFormat == .json ? scanner.exportJSON() : scanner.exportCSV() {
                ShareLink(item: data, preview: .init("Network Scan", image: Image(systemName: "network"))) {
                    Text("Export")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Export") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var hostSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(hostsByRole, id: \.0) { role, hosts in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: role.symbol)
                            .foregroundStyle(role.color)
                        Text("\(role.rawValue) (\(hosts.count))")
                            .font(.headline)
                    }

                    ForEach(hosts) { host in
                        HostRow(host: host,
                                expanded: expanded.contains(host.id),
                                toggleExpand: { if expanded.contains(host.id) { expanded.remove(host.id) } else { expanded.insert(host.id) } })
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }

    private func ipToSortable(_ ip: String) -> UInt32 {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return UInt32.max }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
