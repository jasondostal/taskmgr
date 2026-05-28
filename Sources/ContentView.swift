import SwiftUI

struct ContentView: View {
    @ObservedObject var metrics: MetricsService
    var onPin: (() -> Void)?
    var onQuit: (() -> Void)?

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

            // Core heatmap + disk capacity icon
            if !metrics.metrics.cpu.perCore.isEmpty {
                HStack {
                    Text("Cores")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    CoreHeatmap(perCore: metrics.metrics.cpu.perCore)
                    Spacer()
                    DiskCapacityIcon(percent: metrics.metrics.disk.percentUsed)
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
            DiskRow(
                readHistory: metrics.diskReadHistory,
                writeHistory: metrics.diskWriteHistory,
                readBps: metrics.metrics.disk.readBytesPerSec,
                writeBps: metrics.metrics.disk.writeBytesPerSec
            )
            Divider().padding(.vertical, 2)
            MetricRow(
                label: "Net",
                percent: netPercent,
                detail: netDetail,
                sparkline: metrics.netHistory,
                color: .cyan
            )
        }
        .frame(width: 340)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        // Quit
        if onQuit != nil {
            Divider()
                .padding(.horizontal, 12)
            HStack {
                Spacer()
                Button("Quit TaskMgr") { onQuit?() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(width: 340)
        }
    }

    private var gpuDetail: String {
        let c = metrics.metrics.gpu.coreCount
        let cores = c > 0 ? "\(c) cores" : ""
        let vram = metrics.metrics.gpu.memoryUsedBytes.map { ", \($0.sizeString)" } ?? ""
        return "\(cores)\(vram)"
    }

    /// Network throughput as % of 1 Gbps reference
    private var netPercent: Double {
        let totalBps = Double(metrics.metrics.network.rxBytesPerSec + metrics.metrics.network.txBytesPerSec)
        let gbps = 125_000_000.0 // 1 Gbps in bytes/sec
        return min(totalBps / gbps * 100.0, 100.0)
    }

    private var netDetail: String {
        let rx = metrics.metrics.network.rxBytesPerSec
        let tx = metrics.metrics.network.txBytesPerSec
        let ifaces = metrics.metrics.network.interfaceCount
        if rx == 0 && tx == 0 && ifaces == 0 { return "no interfaces" }
        if rx == 0 && tx == 0 { return "\(ifaces) interface\(ifaces == 1 ? "" : "es") idle" }
        return "↓\(rx.sizeString)/s  ↑\(tx.sizeString)/s"
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

struct DiskCapacityIcon: View {
    let percent: Double

    private var fillColor: Color {
        switch percent {
        case ..<60: return .green
        case ..<85: return .yellow
        default:    return .red
        }
    }

    var body: some View {
        ZStack {
            // Background: the drive icon outline
            Image(systemName: "internaldrive")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.3))

            // Fill: clipped to the drive shape
            GeometryReader { geo in
                let fillHeight = geo.size.height * CGFloat(min(percent, 100) / 100)
                Rectangle()
                    .fill(fillColor)
                    .frame(height: fillHeight)
                    .offset(y: geo.size.height - fillHeight)
            }
            .mask(
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
            )
        }
        .frame(width: 16, height: 14)
        .help(String(format: "Disk %.0f%% used", percent))
    }
}

struct DiskRow: View {
    let readHistory: [Double]
    let writeHistory: [Double]
    let readBps: UInt64
    let writeBps: UInt64

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                Text("Disk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if readBps > 0 || writeBps > 0 {
                    Text("↓\(readBps.sizeString)/s  ↑\(writeBps.sizeString)/s")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                } else {
                    Text("idle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 4) {
                // Read sparkline
                if readHistory.count > 1 {
                    Sparkline(data: readHistory, color: .green.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 14)
                }
                // Write sparkline
                if writeHistory.count > 1 {
                    Sparkline(data: writeHistory, color: .teal.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 14)
                }
            }
        }
    }
}
