import SwiftUI

struct TopologyView: View {
    let hosts: [Host]

    private struct Node: Identifiable {
        let id = UUID()
        let label: String
        let role: Host.Role
        let color: Color
    }

    private struct Edge: Identifiable {
        let id = UUID()
        let from: Int
        let to: Int
    }

    private var nodes: [Node] {
        hosts.map { h in
            Node(label: h.displayName ?? h.hostname ?? h.ipAddress,
                 role: h.role,
                 color: h.iconColor)
        }
    }

    private var edges: [Edge] {
        guard let gatewayIndex = hosts.firstIndex(where: { $0.ipAddress.hasSuffix(".1") }) else { return [] }
        return hosts.enumerated().compactMap { idx, _ in
            idx == gatewayIndex ? nil : Edge(from: gatewayIndex, to: idx)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let positions = layout(nodes: nodes, in: size)

            ZStack {
                ForEach(edges) { e in
                    let p1 = positions[e.from]
                    let p2 = positions[e.to]
                    Path { path in
                        path.move(to: p1)
                        path.addLine(to: p2)
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                ForEach(Array(nodes.enumerated()), id: \.offset) { idx, node in
                    let p = positions[idx]
                    VStack(spacing: 4) {
                        Image(systemName: node.role.symbol)
                            .foregroundStyle(node.color)
                        Text(node.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 80)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .position(p)
                }
            }
        }
    }

    private func layout(nodes: [Node], in size: CGSize) -> [CGPoint] {
        guard !nodes.isEmpty else { return [] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var positions = Array(repeating: center, count: nodes.count)

        let routerIndices = nodes.enumerated().filter { $0.element.role == .router }.map { $0.offset }
        let centerIndex = routerIndices.first ?? 0
        positions[centerIndex] = center

        let groups: [Host.Role: [Int]] = Dictionary(grouping: nodes.indices.filter { $0 != centerIndex }) { nodes[$0].role }

        let ringRoles: [Host.Role] = [.server, .workstation, .printer, .appliance, .unknown]
        var ringRadius: CGFloat = min(size.width, size.height) * 0.35
        for role in ringRoles {
            guard let idxs = groups[role], !idxs.isEmpty else { continue }
            let count = idxs.count
            for (i, idx) in idxs.enumerated() {
                let angle = (Double(i) / Double(count)) * (2 * Double.pi)
                let x = center.x + cos(angle) * ringRadius
                let y = center.y + sin(angle) * ringRadius * 0.6
                positions[idx] = CGPoint(x: x, y: y)
            }
            ringRadius *= 0.82
        }

        return positions
    }
}
