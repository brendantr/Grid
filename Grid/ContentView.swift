//
//  ContentView.swift
//  Grid
//
//  Created by Brendan Rodriguez on 1/6/26.
//

import SwiftUI
import Combine

struct Host: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String

    // Discovered info
    var hostname: String?
    var openPorts: [UInt16] = []

    // Identification
    var deviceType: String {
        let p = Set(openPorts)

        if ipAddress.hasSuffix(".1") && (p.contains(80) || p.contains(443)) {
            return "Likely router"
        } else if (p.contains(9100) || p.contains(631)) {
            return "Likely printer"
        } else if p.contains(22) && (p.contains(445) || p.contains(139) || p.contains(2049) || p.contains(8080)) {
            return "Likely NAS / server"
        } else if p.contains(3389) {
            return "Likely Windows host (RDP)"
        } else if p.contains(22) {
            return "Likely Unix-like host (SSH)"
        } else if p.contains(80) || p.contains(443) {
            return "Likely web server / appliance"
        } else {
            return "Unknown device"
        }
    }

    // User labeling
    var displayName: String?
    var notes: String?

    var isOnline: Bool
}

private extension Host {
    var title: String {
        displayName ?? hostname ?? ipAddress
    }

    var subtitle: String? {
        if let name = hostname, name != title {
            return name
        }
        return nil
    }

    var iconName: String {
        switch deviceType {
        case _ where deviceType.contains("router"):
            return "wifi.router"
        case _ where deviceType.contains("printer"):
            return "printer"
        case _ where deviceType.contains("NAS"):
            return "externaldrive"
        case _ where deviceType.contains("Windows"):
            return "desktopcomputer"
        case _ where deviceType.contains("Unix"):
            return "terminal"
        case _ where deviceType.contains("web"):
            return "globe"
        default:
            return "questionmark.app"
        }
    }

    var iconColor: Color {
        isOnline ? .green : .gray
    }
}

// MARK: - App Entry (Home -> Scan flow)

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                NetworkBackground()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Grid")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Discover devices on your network with smart port scanning and reverse DNS.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }

                    VStack(spacing: 12) {
                        Button {
                            path.append(Route.scan)
                        } label: {
                            Label("Scan Network", systemImage: "wave.3.right")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: 340)
                        }
                        .buttonStyle(.borderedProminent)

                        Text("You can return here anytime using the back button.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .ignoresSafeArea()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .scan:
                    ScanView()
                }
            }
        }
    }

    enum Route: Hashable {
        case scan
    }
}

// MARK: - Scan Screen (moved from previous ContentView body)

struct ScanView: View {
    @EnvironmentObject private var scanner: NetworkScanner

    @State private var sortMode: SortMode = .ipAscending
    @State private var filterText: String = ""

    enum SortMode: String, CaseIterable, Identifiable {
        case ipAscending = "IP"
        case nameAscending = "Name"
        case portsDescending = "Ports"

        var id: String { rawValue }
    }

    private var filteredAndSortedHosts: [Host] {
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

        switch sortMode {
        case .ipAscending:
            hosts.sort { lhs, rhs in
                ipToSortable(lhs.ipAddress) < ipToSortable(rhs.ipAddress)
            }
        case .nameAscending:
            hosts.sort { lhs, rhs in
                (lhs.displayName ?? lhs.hostname ?? lhs.ipAddress)
                <
                (rhs.displayName ?? rhs.hostname ?? rhs.ipAddress)
            }
        case .portsDescending:
            hosts.sort { lhs, rhs in
                lhs.openPorts.count > rhs.openPorts.count
            }
        }

        return hosts
    }

    var body: some View {
        ZStack {
            NetworkBackground()

            VStack(spacing: 10) {
                header

                if scanner.hosts.isEmpty && !scanner.isScanning {
                    emptyState
                } else {
                    listSection
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Host.self) { host in
                HostDetailView(host: host)
            }
        }
        .ignoresSafeArea()
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
                    scanner.scanDemoRange()
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
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No hosts yet")
                .font(.headline)
            Text("Tap Scan to discover devices on your network.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }

    private var listSection: some View {
        List {
            ForEach(filteredAndSortedHosts) { host in
                NavigationLink(value: host) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(host.iconColor.opacity(0.18))
                                .frame(width: 34, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(host.iconColor.opacity(0.35), lineWidth: 1)
                                )
                            Image(systemName: host.iconName)
                                .imageScale(.small)
                                .foregroundStyle(host.iconColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            HStack(spacing: 6) {
                                Text(host.ipAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let sub = host.subtitle {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }

                            Text(host.deviceType)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer()

                        if !host.openPorts.isEmpty {
                            Text("\(host.openPorts.count)")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                    }
                    .padding(.vertical, 3)
                }
                .swipeActions {
                    Button {
                        Task { await scanner.refreshHost(host) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .contextMenu {
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .refreshable {
            await scanner.rescan()
        }
    }

    private func ipToSortable(_ ip: String) -> UInt32 {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return UInt32.max }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }
}

// MARK: - Host Detail

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
                LabeledContent("Type", value: host.deviceType)
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
        let updated = await scanner.scanPorts(for: host)
        await MainActor.run {
            host = updated
            isScanningPorts = false
        }
    }

    private func commonServices(for ports: [UInt16]) -> String {
        let names: [UInt16: String] = [
            21: "FTP",
            22: "SSH",
            53: "DNS",
            80: "HTTP",
            139: "NetBIOS",
            443: "HTTPS",
            445: "SMB",
            631: "IPP",
            8080: "HTTP-alt",
            8443: "HTTPS-alt",
            9100: "JetDirect",
            3389: "RDP"
        ]
        return ports.compactMap { names[$0] }.joined(separator: ", ")
    }
}

// MARK: - Background

private struct NetworkBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            GridLines(phase: phase)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                .blendMode(.plusLighter)
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: phase)

            RadialGradient(colors: [Color.green.opacity(0.08), .clear],
                           center: .center,
                           startRadius: 0,
                           endRadius: 500)
                .blendMode(.screen)
        }
        .onAppear { phase = 1 }
    }
}

private struct GridLines: Shape {
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28
        let offset = (phase.truncatingRemainder(dividingBy: 1)) * spacing

        // Vertical lines
        var x = rect.minX - offset
        while x <= rect.maxX + spacing {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        // Horizontal lines
        var y = rect.minY - offset
        while y <= rect.maxY + spacing {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        return path
    }

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
}

#Preview {
    ContentView()
}
