import SwiftUI

struct HostRow: View {
    let host: Host
    let expanded: Bool
    let toggleExpand: () -> Void

    private var serviceChips: [String] {
        host.openPorts.map { CommonPortNames[$0] ?? "\($0)" }.sorted()
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
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
                    HStack(spacing: 6) {
                        Text(host.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Circle().fill(host.isOnline ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)

                        if let ms = host.latencyMs {
                            Text(String(format: "%.0f ms", ms))
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        if host.isNew {
                            Text("NEW")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.25)))
                        } else if host.hasChanged {
                            Text("CHANGED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.25)))
                        }
                    }

                    HStack(spacing: 6) {
                        Text(host.ipAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let sub = host.subtitle {
                            Text("•").foregroundStyle(.secondary)
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }

                Spacer()

                if !host.openPorts.isEmpty {
                    Text("\(host.openPorts.count)")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Material.ultraThin))
                }

                Button(action: toggleExpand) {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Type: \(host.deviceType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !serviceChips.isEmpty {
                        FlexibleChips(chips: serviceChips)
                    }

                    if let notes = host.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = host.ipAddress
                        } label: {
                            Label("Copy IP", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        if let name = host.hostname {
                            Button {
                                UIPasteboard.general.string = name
                            } label: {
                                Label("Copy Hostname", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
