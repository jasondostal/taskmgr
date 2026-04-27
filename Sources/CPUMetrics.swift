import Foundation

final class CPUCollector {
    private var previousTickData: Data?

    func collect() -> (overall: Double, perCore: [Double]) {
        var cpuCount: natural_t = 0
        var ticks: processor_info_array_t?
        var count: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &ticks,
            &count
        )

        guard result == KERN_SUCCESS, let tickPtr = ticks, cpuCount > 0 else {
            return (0, [])
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: tickPtr), vm_size_t(MemoryLayout<integer_t>.stride * Int(count)))
        }

        let coreCount = Int(cpuCount)
        let statesPerCore = Int(CPU_STATE_MAX)
        let totalStates = coreCount * statesPerCore

        let currentData = Data(bytes: tickPtr, count: totalStates * MemoryLayout<integer_t>.stride)

        guard let prevData = previousTickData else {
            previousTickData = currentData
            return (0, Array(repeating: 0, count: coreCount))
        }

        previousTickData = currentData

        let curr = currentData.withUnsafeBytes { $0.bindMemory(to: Int32.self) }
        let prev = prevData.withUnsafeBytes { $0.bindMemory(to: Int32.self) }

        var perCore: [Double] = []
        var totalUsed: Int64 = 0
        var totalTicks: Int64 = 0

        for i in 0..<coreCount {
            let base = i * statesPerCore
            let user = Int64(curr[base]) - Int64(prev[base])
            let sys  = Int64(curr[base + 1]) - Int64(prev[base + 1])
            let idle = Int64(curr[base + 2]) - Int64(prev[base + 2])
            let nice = Int64(curr[base + 3]) - Int64(prev[base + 3])

            let coreTotal = user + sys + idle + nice
            let coreUsed = user + sys + nice
            let pct = coreTotal > 0 ? Double(coreUsed) / Double(coreTotal) * 100.0 : 0
            perCore.append(min(pct, 100))

            totalUsed += coreUsed
            totalTicks += coreTotal
        }

        let overall = totalTicks > 0 ? Double(totalUsed) / Double(totalTicks) * 100.0 : 0

        return (min(overall, 100), perCore)
    }
}
