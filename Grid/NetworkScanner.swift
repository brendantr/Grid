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

    private var scanTask: Task<Void, Never>?

    struct ScanProgress {
        var current: Int
        var total: Int
        var label: String

        var fractionCompleted: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
    }

    // MARK: - Public API

    func scanDemoRange() {
        cancelScan()
        hosts = []
        isScanning = true

        let base = "192.168.1."
        let ipRange = Array(1...254).map { base + String($0) }
        let portsToCheck: [UInt16] = [80, 443, 22, 3389]
        let timeout: TimeInterval = 0.5

        progress = .init(current: 0, total: ipRange.count, label: "Scanning \(ipRange.count) hosts")

        scanTask = Task { [weak self] in
            guard let self else { return }

            // Limit overall concurrency to a reasonable number
            let concurrencyLimit = 64
            let semaphore = AsyncSemaphore(value: concurrencyLimit)

            await withTaskGroup(of: (String, Bool).self) { group in
                for ip in ipRange {
                    if Task.isCancelled { break }
                    await semaphore.acquire()
                    group.addTask {
                        defer {
                            Task { await semaphore.release() }
                        }
                        let online = await NetworkScanner.isHostReachable(
                            ip: ip,
                            ports: portsToCheck,
                            timeout: timeout
                        )
                        return (ip, online)
                    }
                }

                for await (ip, online) in group {
                    if Task.isCancelled { break }
                    self.progress.current += 1

                    if online {
                        let host = Host(ipAddress: ip, hostname: nil, isOnline: true)
                        if !self.hosts.contains(host) {
                            self.hosts.append(host)
                        }

                        // Reverse DNS in background, then update
                        Task.detached { [weak self] in
                            guard let self else { return }
                            if let name = await Self.reverseDNS(ip: ip) {
                                await MainActor.run {
                                    if let idx = self.hosts.firstIndex(where: { $0.ipAddress == ip }) {
                                        self.hosts[idx].hostname = name
                                    }
                                }
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.progress = .init(current: self.progress.total, total: self.progress.total, label: "Done")
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
        scanDemoRange()
    }

    func refreshHost(_ host: Host) async {
        let updated = await scanPorts(for: host)
        await MainActor.run {
            if let idx = hosts.firstIndex(of: host) {
                hosts[idx] = updated
            }
        }
    }
}

extension NetworkScanner {
    func scanPorts(for host: Host) async -> Host {
        let ports: [UInt16] = [21, 22, 53, 80, 443, 139, 445, 631, 8080, 8443, 9100, 3389]
        let timeout: TimeInterval = 0.5
        var open: [UInt16] = []

        await withTaskGroup(of: (UInt16, Bool).self) { group in
            for port in ports {
                group.addTask {
                    let ok = await NetworkScanner.connectTCP(ip: host.ipAddress, port: port, timeout: timeout)
                    return (port, ok)
                }
            }

            for await (port, ok) in group {
                if ok {
                    open.append(port)
                }
            }
        }

        var updated = host
        updated.openPorts = open.sorted()
        return updated
    }
}


// MARK: - Helpers (nonisolated to allow parallel work)

private extension NetworkScanner {
    nonisolated static func isHostReachable(
        ip: String,
        ports: [UInt16],
        timeout: TimeInterval
    ) async -> Bool {
        await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for port in ports {
                group.addTask {
                    await connectTCP(ip: ip, port: port, timeout: timeout)
                }
            }

            for await success in group {
                if success {
                    group.cancelAll()
                    return true
                }
            }
            return false
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
