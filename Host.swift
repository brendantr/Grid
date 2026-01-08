import SwiftUI

struct Host: Identifiable, Hashable, Codable {
    let id: UUID
    let ipAddress: String

    // Discovered info
    var hostname: String?
    var openPorts: [UInt16]

    // User labeling
    var displayName: String?
    var notes: String?

    // Status
    var isOnline: Bool
    var latencyMs: Double?
    var lastSeen: Date

    // Transient UI flags (not persisted directly; computed/merged)
    var isNew: Bool = false
    var hasChanged: Bool = false

    init(
        id: UUID = UUID(),
        ipAddress: String,
        hostname: String? = nil,
        openPorts: [UInt16] = [],
        displayName: String? = nil,
        notes: String? = nil,
        isOnline: Bool,
        latencyMs: Double? = nil,
        lastSeen: Date = Date(),
        isNew: Bool = false,
        hasChanged: Bool = false
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.openPorts = openPorts
        self.displayName = displayName
        self.notes = notes
        self.isOnline = isOnline
        self.latencyMs = latencyMs
        self.lastSeen = lastSeen
        self.isNew = isNew
        self.hasChanged = hasChanged
    }

    enum CodingKeys: String, CodingKey {
        case id, ipAddress, hostname, openPorts, displayName, notes, isOnline, latencyMs, lastSeen
    }
}

// MARK: - Semantics / Presentation helpers

extension Host {
    var title: String {
        displayName ?? hostname ?? ipAddress
    }

    var subtitle: String? {
        if let name = hostname, name != title { return name }
        return nil
    }

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
        isOnline ? Color.green : Color.gray
    }

    var role: Role {
        if deviceType.contains("router") { return .router }
        if deviceType.contains("printer") { return .printer }
        if deviceType.contains("NAS") || deviceType.contains("server") { return .server }
        if deviceType.contains("Windows") || deviceType.contains("Unix") { return .workstation }
        if deviceType.contains("web") { return .appliance }
        return .unknown
    }

    enum Role: String, CaseIterable, Identifiable {
        case router = "Router"
        case server = "Server/NAS"
        case printer = "Printer"
        case workstation = "Workstation"
        case appliance = "Appliance"
        case unknown = "Unknown"

        var id: String { rawValue }
        var color: Color {
            switch self {
            case .router: return .green
            case .server: return .blue
            case .printer: return .purple
            case .workstation: return .teal
            case .appliance: return .orange
            case .unknown: return .gray
            }
        }
        var symbol: String {
            switch self {
            case .router: return "wifi.router"
            case .server: return "server.rack"
            case .printer: return "printer"
            case .workstation: return "desktopcomputer"
            case .appliance: return "globe"
            case .unknown: return "questionmark.app"
            }
        }
    }
}

