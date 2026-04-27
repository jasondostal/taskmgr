import Foundation
import IOKit

enum GPUMetrics {
    static func collect() -> SystemMetrics.GPU {
        var utilization: Double = 0
        var memoryUsed: UInt64? = nil
        var coreCount = 0

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS,
              iterator != 0
        else {
            return SystemMetrics.GPU(utilizationPercent: 0, memoryUsedBytes: nil, coreCount: 0)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {

                // GPU core count
                if let gpuConfig = dict["GPUConfigurationVariable"] as? [String: Any],
                   let cores = gpuConfig["num_cores"] as? Int {
                    coreCount = cores
                } else if let cores = dict["gpu-core-count"] as? Int {
                    coreCount = cores
                }

                guard let perfStats = dict["PerformanceStatistics"] as? [String: Any] else {
                    service = IOIteratorNext(iterator)
                    continue
                }

                // Utilization: can be Int or Double from IOKit
                if let val = perfStats["Device Utilization %"] {
                    utilization = numberToDouble(val)
                }

                // GPU memory: "In use system memory" = unified memory allocated for GPU
                if let mem = perfStats["In use system memory"] {
                    memoryUsed = numberToUInt64(mem)
                } else if let mem = perfStats["Alloc system memory"] {
                    memoryUsed = numberToUInt64(mem)
                }
            }

            service = IOIteratorNext(iterator)
        }

        return SystemMetrics.GPU(
            utilizationPercent: utilization,
            memoryUsedBytes: memoryUsed,
            coreCount: coreCount
        )
    }

    private static func numberToDouble(_ val: Any) -> Double {
        switch val {
        case let d as Double: return d
        case let i as Int:    return Double(i)
        case let n as NSNumber: return n.doubleValue
        default:              return 0
        }
    }

    private static func numberToUInt64(_ val: Any) -> UInt64? {
        switch val {
        case let i as UInt64: return i
        case let i as Int:    return i >= 0 ? UInt64(i) : nil
        case let d as Double: return UInt64(d)
        case let n as NSNumber: return n.uint64Value
        default:              return nil
        }
    }
}
