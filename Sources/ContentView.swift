import SwiftUI

struct ContentView: View {
    @ObservedObject var metrics: MetricsService
    var onPin: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with pin button
            HStack {
                Spacer()
                if onPin != nil {
                    Button(action: { onPin?() }) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Detach into window")
                    .padding(4)
                }
            }
            .padding(.bottom, 2)

            // Core heatmap
            if !metrics.metrics.cpu.perCore.isEmpty {
                HStack {
                    Text("Cores")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    CoreHeatmap(perCore: metrics.metrics.cpu.perCore)
                    Spacer()
                }
                .padding(.bottom, 4)
            }

            // Metrics with sparklines
            MetricRow(
                label: "CPU",
                percent: metrics.metrics.cpu.overallPercent,
                detail: "\(metrics.metrics.cpu.perCore.count) cores",
                sparkline: metrics.cpuHistory,
                color: cpuColor
            )
            Divider().padding(.vertical, 2)
            MetricRow(
                label: "GPU",
                percent: metrics.metrics.gpu.utilizationPercent,
                detail: gpuDetail,
                sparkline: metrics.gpuHistory,
                color: .orange
            )
            Divider().padding(.vertical, 2)
            MetricRow(
                label: "Memory",
                percent: metrics.metrics.memory.percentUsed,
                detail: "\(metrics.metrics.memory.usedBytes.sizeString) / \(metrics.metrics.memory.totalBytes.sizeString)",
                sparkline: metrics.memHistory,
                color: memoryColor
            )
            Divider().padding(.vertical, 2)
            MetricRow(
                label: "Disk",
                percent: metrics.metrics.disk.percentUsed,
                detail: diskIO,
                sparkline: metrics.diskHistory,
                color: .green
            )
        }
        .frame(width: 340)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var gpuDetail: String {
        let c = metrics.metrics.gpu.coreCount
        let cores = c > 0 ? "\(c) cores" : ""
        let vram = metrics.metrics.gpu.memoryUsedBytes.map { ", \($0.sizeString)" } ?? ""
        return "\(cores)\(vram)"
    }

    private var diskIO: String {
        let r = metrics.metrics.disk.readBytesPerSec
        let w = metrics.metrics.disk.writeBytesPerSec
        if r == 0 && w == 0 { return "" }
        return "R \(r.sizeString)/s  W \(w.sizeString)/s"
    }

    private var cpuColor: Color {
        gradient(metrics.metrics.cpu.overallPercent, thresholds: (50, 80))
    }

    private var memoryColor: Color {
        gradient(metrics.metrics.memory.percentUsed, thresholds: (60, 85))
    }

    private func gradient(_ pct: Double, thresholds: (Double, Double)) -> Color {
        switch pct {
        case ..<thresholds.0: return .green
        case ..<thresholds.1: return .yellow
        default:              return .red
        }
    }
}

struct MetricRow: View {
    let label: String
    let percent: Double
    let detail: String
    let sparkline: [Double]
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", min(percent, 100)))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }

            HStack(spacing: 6) {
                // Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * min(percent / 100.0, 1.0), height: 5)
                    }
                }
                .frame(height: 5)

                // Sparkline
                if sparkline.count > 1 {
                    Sparkline(data: sparkline, color: color.opacity(0.7))
                        .frame(width: 60, height: 14)
                }
            }

            if !detail.isEmpty {
                HStack {
                    Spacer()
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
