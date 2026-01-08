//
//  NetworkScanner.swift
//  Grid
//
//  Created by Brendan Rodriguez on 1/6/26.
//

import Foundation
import Combine
import Network

@MainActor
final class NetworkScanner: ObservableObject {
    @Published var hosts: [Host] = []
    @Published var isScanning = false
    @Published var progress: ScanProgress = .init(current: 0, total: 0, label: "")
    @Published var activeSubnetDescription: String = "Auto"
    @Published var selectedProfile: ScanProfile = .quick

    private var scanTask: Task<Void, Never>?
    private let persistence = Persistence()

    struct ScanProgress {
        var current: Int
        var total: Int
        var label: String

        var fractionCompleted: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
    }

    enum ScanProfile: String, CaseIterable, Identifiable {
        case quick = "Quick"
        case standard = "Standard"
        case web = "Web"
        case admin = "Admin"
        case printer = "Printer"

        var id: String { rawValue }

        var ports: [UInt16] {
            switch self {
            case .quick:
                return [21,22,53,80,139,443,445,631,8080,8443,9100,3389]
            case .standard:
                // A broader set of commonly used ports (curated but still modest)
                return [20,21,22,23,25,53,67,68,69,80,110,123,135,137,138,139,143,161,162,179,389,443,445,465,500,514,515,587,631,636,993,995,1080,1433,1521,1723,1883,2049,2375,2376,2483,2484,3000,3128,3268,3269,3306,3389,4444,5000,5432,5672,5900,5985,5986,6379,7001,8000,8080,8081,8443,8530,8531,8888,9000,9001,9100,9200,9300,10000]
            case .web:
                return [80,443,8080,8443,8000,8888]
            case .admin:
                return [22,3389,5985,5986,5900,8530,8531]
            case .printer:
                return [631,9100,515]
            }
        }
    }

    // MARK: - Init

    init() {
        // Load persisted hosts (if any)
        if let saved = persistence.load() {
            self.hosts = saved
        }
    }

    // MARK: - Public API

    func scan(profile: ScanProfile? = nil) {
        if let p = profile { selectedProfile = p }
        cancelScan()

        let subnet = Self.discoverActiveSubnet() ?? ("192.168.1.", 24, Array(1...254))
        let base = subnet.0
        let range = subnet.2
        self.activeSubnetDescription = "Auto \(base)0/\(subnet.1)"

        hosts = mergePersisted(into: [])
        isScanning = true

        let ipRange = range.map { base + String($0) }
        let portsToCheck = selectedProfile.ports
        let timeout: TimeInterval = 0.7

        progress = .init(current: 0, total: ipRange.count, label: "Scanning \(ipRange.count) hosts (\(selectedProfile.rawValue))")

        scanTask = Task { [weak self] in
            guard let self else { return }

            // Limit overall concurrency to a reasonable number
            let concurrencyLimit = 64
            let semaphore = AsyncSemaphore(value: concurrencyLimit)

            await withTaskGroup(of: (String, Host?).self) { group in
                for ip in ipRange {
                    if Task.isCancelled { break }
                    await semaphore.acquire()
                    group.addTask {
                        defer { Task { await semaphore.release() } }
                        let result = await Self.probeHost(ip: ip, ports: portsToCheck, timeout: timeout)
                        return (ip, result)
                    }
                }

                for await (ip, hostOpt) in group {
                    if Task.isCancelled { break }
                    self.progress.current += 1

                    if var host = hostOpt {
                        // Merge with any persisted labels/notes and compute change flags
                        host = self.mergeWithPersisted(host: host)
                        if let idx = self.hosts.firstIndex(where: { $0.ipAddress == ip }) {
                            self.hosts[idx] = host
                        } else {
                            self.hosts.append(host)
                        }

                        // Reverse DNS in background, then update
                        Task.detached { [weak self] in
                            guard let self else { return }
                            if let name = await Self.reverseDNS(ip: ip) {
                                await MainActor.run {
                                    if let idx = self.hosts.firstIndex(where: { $0.ipAddress == ip }) {
                                        self.hosts[idx].hostname = name
                                        self.save()
                                    }
                                }
                            }
                        }
                    }

                    if self.progress.current % 8 == 0 {
                        self.save()
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.progress = .init(current: self.progress.total, total: self.progress.total, label: "Done")
                self.save()
                self.scanTask = nil
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        progress = .init(current: 0, total: 0, label: "")
    }

    func rescan() async {
        scan()
    }

    func refreshHost(_ host: Host) async {
        let portsToCheck = selectedProfile.ports
        let timeout: TimeInterval = 0.7
        if var updated = await Self.probeHost(ip: host.ipAddress, ports: portsToCheck, timeout: timeout) {
            updated = mergeWithPersisted(host: updated)
            if let idx = hosts.firstIndex(where: { $0.ipAddress == host.ipAddress }) {
                hosts[idx] = updated
            } else {
                hosts.append(updated)
            }
            save()
        }
    }

    // Export

    func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(hosts)
    }

    func exportCSV() -> Data? {
        var lines: [String] = ["ipAddress,hostname,isOnline,latencyMs,openPorts,displayName,notes,lastSeen"]
        let df = ISO8601DateFormatter()
        for h in hosts {
            let ports = h.openPorts.map(String.init).joined(separator: "|")
            let line = [
                h.ipAddress,
                h.hostname ?? "",
                h.isOnline ? "1" : "0",
                h.latencyMs.map { String(format: "%.0f", $0) } ?? "",
                "\"\(ports)\"",
                "\"\(h.displayName ?? "")\"",
                "\"\(h.notes ?? "")\"",
                df.string(from: h.lastSeen)
            ].joined(separator: ",")
            lines.append(line)
        }
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    // MARK: - Persistence

    private func save() {
        persistence.save(hosts: hosts)
    }

    private func mergePersisted(into fresh: [Host]) -> [Host] {
        guard let saved = persistence.load() else { return fresh }
        var merged: [Host] = []
        for s in saved {
            var copy = s
            copy.isNew = false
            copy.hasChanged = false
            merged.append(copy)
        }
        return merged
    }

    private func mergeWithPersisted(host: Host) -> Host {
        guard let saved = persistence.load(),
              let existing = saved.first(where: { $0.ipAddress == host.ipAddress }) else {
            var h = host
            h.isNew = true
            h.hasChanged = false
            return h
        }
        var merged = host
        merged.displayName = existing.displayName
        merged.notes = existing.notes

        // Change detection
        let oldPorts = Set(existing.openPorts)
        let newPorts = Set(host.openPorts)
        merged.isNew = false
        merged.hasChanged = oldPorts != newPorts
        return merged
    }
}

// MARK: - Scanning helpers (nonisolated)

private extension NetworkScanner {
    nonisolated static func probeHost(ip: String, ports: [UInt16], timeout: TimeInterval) async -> Host? {
        // Attempt TCP connects to given ports; if any succeed, host is "online".
        var open: [UInt16] = []
        var bestLatency: Double?

        await withTaskGroup(of: (UInt16, Bool, Double?).self) { group in
            for port in ports {
                group.addTask {
                    let (ok, ms) = await timedConnectTCP(ip: ip, port: port, timeout: timeout)
                    return (port, ok, ms)
                }
            }

            for await (port, ok, ms) in group {
                if ok {
                    open.append(port)
                    if let ms, let current = bestLatency {
                        if ms < current { bestLatency = ms }
                    } else if let ms {
                        bestLatency = ms
                    }
                }
            }
        }

        guard !open.isEmpty else { return nil }

        return await Host(
            ipAddress: ip,
            hostname: nil,
            openPorts: open.sorted(),
            displayName: nil,
            notes: nil,
            isOnline: true,
            latencyMs: bestLatency,
            lastSeen: Date(),
            isNew: true,
            hasChanged: false
        )
    }

    nonisolated static func timedConnectTCP(
        ip: String,
        port: UInt16,
        timeout: TimeInterval
    ) async -> (Bool, Double?) {
        let start = DispatchTime.now().uptimeNanoseconds
        let ok = await connectTCP(ip: ip, port: port, timeout: timeout)
        if ok {
            let end = DispatchTime.now().uptimeNanoseconds
            let ms = Double(end - start) / 1_000_000.0
            return (true, ms)
        } else {
            return (false, nil)
        }
    }

    nonisolated static func connectTCP(
        ip: String,
        port: UInt16,
        timeout: TimeInterval
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let endpoint = NWEndpoint.hostPort(
                host: .init(ip),
                port: .init(rawValue: port)!
            )

            let connection = NWConnection(to: endpoint, using: params)

            // Use a serial queue to ensure only one path resumes the continuation.
            let queue = DispatchQueue(label: "grid.connect.\(ip).\(port)")
            var resumed = false

            @Sendable func finish(_ result: Bool) {
                queue.async {
                    guard !resumed else { return }
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: result)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Enforce timeout
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }
        }
    }

    nonisolated static func reverseDNS(ip: String) async -> String? {
        await withCheckedContinuation { continuation in
            var hints = addrinfo(
                ai_flags: AI_NUMERICHOST,
                ai_family: AF_INET,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )

            var res: UnsafeMutablePointer<addrinfo>?
            let rc = getaddrinfo(ip, nil, &hints, &res)
            guard rc == 0, let info = res?.pointee, let addr = info.ai_addr else {
                continuation.resume(returning: nil)
                if res != nil { freeaddrinfo(res) }
                return
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let err = getnameinfo(addr, socklen_t(info.ai_addrlen),
                                  &hostBuffer, socklen_t(hostBuffer.count),
                                  nil, 0, NI_NAMEREQD)
            if err == 0 {
                continuation.resume(returning: String(cString: hostBuffer))
            } else {
                continuation.resume(returning: nil)
            }
            if res != nil { freeaddrinfo(res) }
        }
    }

    // Returns (base "a.b.c.", cidr, host range 1...N) or nil
    nonisolated static func discoverActiveSubnet() -> (String, Int, [Int])? {
        // Use NWPathMonitor to get interface? Not synchronous. Instead, use getifaddrs.
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var best: (addr: in_addr, mask: in_addr)?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cursor?.pointee {
            defer { cursor = p.ifa_next }
            guard p.ifa_addr?.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            if let addr_in = UnsafePointer<sockaddr_in>(OpaquePointer(p.ifa_addr))?.pointee,
               let mask_in = UnsafePointer<sockaddr_in>(OpaquePointer(p.ifa_netmask))?.pointee {
                let addr = addr_in.sin_addr
                let mask = mask_in.sin_addr
                // Skip 127.0.0.0/8
                if (addr.s_addr & 0xFF) == 127 { continue }
                best = (addr, mask)
                break
            }
        }

        guard let best else { return nil }

        let hostOrderAddr = best.addr.s_addr.byteSwapped
        let hostOrderMask = best.mask.s_addr.byteSwapped
        let network = hostOrderAddr & hostOrderMask
        let cidr = maskToCIDR(hostOrderMask)

        // Build base like "a.b.c."
        let a = (network >> 24) & 0xFF
        let b = (network >> 16) & 0xFF
        let c = (network >> 8) & 0xFF
        let base = "\(a).\(b).\(c)."

        // Determine host range size
        let hostBits = 32 - cidr
        let count = max(2, Int(pow(2.0, Double(hostBits))) - 2) // exclude network/broadcast if reasonable
        let range = Array(1...min(count, 254))
        return (base, cidr, range)
    }

    nonisolated static func maskToCIDR(_ mask: UInt32) -> Int {
        var m = mask
        var cidr = 0
        while m != 0 {
            cidr += Int(m & 1)
            m >>= 1
        }
        return cidr
    }
}

// MARK: - AsyncSemaphore

private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = max(1, value)
    }

    func acquire() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    func release() async {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - Persistence

private final class Persistence {
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("hosts.json")
    }

    func load() -> [Host]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Host].self, from: data)
    }

    func save(hosts: [Host]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(hosts) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

