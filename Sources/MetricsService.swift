import Foundation
import Combine

final class MetricsService: ObservableObject {
    private static let historyMax = 30

    @Published var metrics = SystemMetrics(
        cpu: SystemMetrics.CPU(overallPercent: 0, perCore: []),
        gpu: SystemMetrics.GPU(utilizationPercent: 0, memoryUsedBytes: nil, coreCount: 0),
        memory: SystemMetrics.Memory(usedBytes: 0, totalBytes: 0),
        disk: SystemMetrics.Disk(totalBytes: 0, freeBytes: 0, readBytesPerSec: 0, writeBytesPerSec: 0),
        network: SystemMetrics.Network(rxBytesPerSec: 0, txBytesPerSec: 0, interfaceCount: 0),
        timestamp: Date()
    )

    @Published var cpuHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var diskReadHistory: [Double] = []
    @Published var diskWriteHistory: [Double] = []
    @Published var netHistory: [Double] = []

    private let cpuCollector = CPUCollector()
    private let diskCollector = DiskCollector()
    private let networkCollector = NetworkCollector()
    private var timer: Timer?

    func start(interval: TimeInterval = 2.0) {
        _ = cpuCollector.collect()
        _ = diskCollector.collect()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let (cpuOverall, cpuPerCore) = self.cpuCollector.collect()
            let gpu = GPUMetrics.collect()
            let memory = MemoryMetrics.collect()
            let disk = self.diskCollector.collect()
            let network = self.networkCollector.collect()

            let metric = SystemMetrics(
                cpu: SystemMetrics.CPU(overallPercent: cpuOverall, perCore: cpuPerCore),
                gpu: gpu,
                memory: memory,
                disk: disk,
                network: network,
                timestamp: Date()
            )

            DispatchQueue.main.async {
                self.metrics = metric
                self.append(&self.cpuHistory, metric.cpu.overallPercent)
                self.append(&self.gpuHistory, metric.gpu.utilizationPercent)
                self.append(&self.memHistory, metric.memory.percentUsed)
                self.append(&self.diskReadHistory, Double(metric.disk.readBytesPerSec) / 1_000_000)
                self.append(&self.diskWriteHistory, Double(metric.disk.writeBytesPerSec) / 1_000_000)
                let netTotal = Double(metric.network.rxBytesPerSec + metric.network.txBytesPerSec) / 1_000_000
                self.append(&self.netHistory, netTotal)
            }
        }
        timer?.tolerance = interval * 0.5
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > Self.historyMax {
            history.removeFirst(history.count - Self.historyMax)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
