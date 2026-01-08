import SwiftUI

struct NetworkBackground: View {
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
        .ignoresSafeArea()
    }
}

struct GridLines: Shape {
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28
        let offset = (phase.truncatingRemainder(dividingBy: 1)) * spacing

        var x = rect.minX - offset
        while x <= rect.maxX + spacing {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

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
