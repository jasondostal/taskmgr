import Foundation

struct SystemMetrics {
    struct CPU {
        let overallPercent: Double
        let perCore: [Double]
    }

    struct GPU {
        let utilizationPercent: Double
        let memoryUsedBytes: UInt64?
        let coreCount: Int
    }

    struct Memory {
        let usedBytes: UInt64
        let totalBytes: UInt64
        var percentUsed: Double {
            totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100.0 : 0
        }
    }

    struct Disk {
        let totalBytes: UInt64
        let freeBytes: UInt64
        let readBytesPerSec: UInt64
        let writeBytesPerSec: UInt64
        var usedBytes: UInt64 { totalBytes - freeBytes }
        var percentUsed: Double {
            totalBytes > 0 ? Double(totalBytes - freeBytes) / Double(totalBytes) * 100.0 : 0
        }
    }

    let cpu: CPU
    let gpu: GPU
    let memory: Memory
    let disk: Disk
    let timestamp: Date
}

extension UInt64 {
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(self))
    }
}
