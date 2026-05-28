import Foundation

final class NetworkCollector {
    private var previousRx: UInt64 = 0
    private var previousTx: UInt64 = 0
    private var previousTime: Date?

    func collect() -> SystemMetrics.Network {
        let (rxBytes, txBytes, interfaceCount) = readInterfaceBytes()
        let now = Date()

        var rxPerSec: UInt64 = 0
        var txPerSec: UInt64 = 0
        if let prev = previousTime {
            let elapsed = now.timeIntervalSince(prev)
            if elapsed > 0 {
                rxPerSec = UInt64(Double(rxBytes - previousRx) / elapsed)
                txPerSec = UInt64(Double(txBytes - previousTx) / elapsed)
            }
        }

        previousRx = rxBytes
        previousTx = txBytes
        previousTime = now

        return SystemMetrics.Network(
            rxBytesPerSec: rxPerSec,
            txBytesPerSec: txPerSec,
            interfaceCount: interfaceCount
        )
    }

    private func readInterfaceBytes() -> (rx: UInt64, tx: UInt64, count: Int) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var count = 0

        var addr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addr) == 0, let first = addr else {
            return (0, 0, 0)
        }
        defer { freeifaddrs(first) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }

            let flags = ifa.pointee.ifa_flags
            // Skip loopback and interfaces that are down
            guard flags & UInt32(IFF_LOOPBACK) == 0,
                  flags & UInt32(IFF_UP) != 0
            else { continue }

            // Must have an address (IPv4 or IPv6)
            guard ifa.pointee.ifa_addr != nil else { continue }

            // Read link-layer data if available
            if let data = ifa.pointee.ifa_data {
                let stats = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                rx += UInt64(stats.ifi_ibytes)
                tx += UInt64(stats.ifi_obytes)
                count += 1
            }
        }

        return (rx, tx, count)
    }
}
