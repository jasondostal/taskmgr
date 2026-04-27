import Foundation

enum MemoryMetrics {
    static func collect() -> SystemMetrics.Memory {
        let pageSize = UInt64(vm_kernel_page_size)
        let totalBytes = UInt64(ProcessInfo.processInfo.physicalMemory)

        var vmInfo = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return SystemMetrics.Memory(usedBytes: 0, totalBytes: totalBytes)
        }

        let activePages = UInt64(vmInfo.active_count)
        let wirePages = UInt64(vmInfo.wire_count)
        let compressedPages = UInt64(vmInfo.compressor_page_count)

        let usedBytes = (activePages + wirePages + compressedPages) * pageSize
        // Clamp to total (can briefly exceed due to compressed pages + wired)
        let clampedUsed = min(usedBytes, totalBytes)

        return SystemMetrics.Memory(usedBytes: clampedUsed, totalBytes: totalBytes)
    }
}
