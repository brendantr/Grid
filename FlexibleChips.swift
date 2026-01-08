import SwiftUI

struct FlexibleChips: View {
    let chips: [String]

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(chips, id: \.self) { chip in
                    chipView(chip)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            width -= d.width
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if chip == chips.last {
                                width = 0
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(height: dynamicHeight(for: chips))
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func dynamicHeight(for chips: [String]) -> CGFloat {
        max(24, CGFloat((chips.count / 4) + 1) * 24)
    }
}
