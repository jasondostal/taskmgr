import Foundation
import IOKit

final class DiskCollector {
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTime: Date?

    func collect() -> SystemMetrics.Disk {
        // Capacity via statfs
        var buf = statfs()
        let totalBytes: UInt64
        let freeBytes: UInt64
        if statfs("/", &buf) == 0 {
            totalBytes = UInt64(buf.f_blocks) * UInt64(buf.f_bsize)
            freeBytes = UInt64(buf.f_bfree) * UInt64(buf.f_bsize)
        } else {
            totalBytes = 0
            freeBytes = 0
        }

        // I/O throughput via IOKit
        let io = readBlockStorageStats()
        let now = Date()

        var readPerSec: UInt64 = 0
        var writePerSec: UInt64 = 0
        if let prev = previousTime {
            let elapsed = now.timeIntervalSince(prev)
            if elapsed > 0 {
                readPerSec = UInt64(Double(io.read - previousRead) / elapsed)
                writePerSec = UInt64(Double(io.write - previousWrite) / elapsed)
            }
        }

        previousRead = io.read
        previousWrite = io.write
        previousTime = now

        return SystemMetrics.Disk(
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            readBytesPerSec: readPerSec,
            writeBytesPerSec: writePerSec
        )
    }

    private func readBlockStorageStats() -> (read: UInt64, write: UInt64) {
        var read: UInt64 = 0
        var write: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS,
              iterator != 0
        else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let r = stats["Bytes (Read)"] as? UInt64 ?? stats["Reads (Bytes)"] as? UInt64 {
                    read += r
                }
                if let w = stats["Bytes (Write)"] as? UInt64 ?? stats["Writes (Bytes)"] as? UInt64 {
                    write += w
                }
            }

            service = IOIteratorNext(iterator)
        }

        return (read, write)
    }
}
