import SwiftUI

struct CoreHeatmap: View {
    let perCore: [Double]

    private let columns = 6

    var body: some View {
        let rows = (perCore.count + columns - 1) / columns
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { col in
                        let idx = row * columns + col
                        if idx < perCore.count {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(colorFor(perCore[idx]))
                                .frame(width: 10, height: 10)
                        } else {
                            Color.clear.frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
    }

    private func colorFor(_ pct: Double) -> Color {
        switch pct {
        case ..<25: return .green.opacity(0.5 + pct / 50)
        case ..<50: return .yellow.opacity(0.5 + (pct - 25) / 50)
        case ..<75: return .orange.opacity(0.5 + (pct - 50) / 50)
        default:    return .red.opacity(0.5 + min((pct - 75) / 50, 0.5))
        }
    }
}
