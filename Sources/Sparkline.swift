import SwiftUI

struct Sparkline: View {
    let data: [Double]
    let color: Color
    var maxValue: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let max = maxValue ?? data.max() ?? 1
            let points = normalize(data: data, width: w, height: h, max: max)

            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for pt in points.dropFirst() {
                    path.addLine(to: pt)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }

    private func normalize(data: [Double], width: CGFloat, height: CGFloat, max: Double) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let effectiveMax = max > 0 ? max : 1
        let pad: CGFloat = 1
        let usableH = height - pad * 2
        return data.enumerated().map { i, val in
            let x = pad + (CGFloat(i) / CGFloat(data.count - 1)) * (width - pad * 2)
            let ratio = min(val / effectiveMax, 1.0)
            let y = pad + usableH * CGFloat(1.0 - ratio)
            return CGPoint(x: x, y: y)
        }
    }
}
