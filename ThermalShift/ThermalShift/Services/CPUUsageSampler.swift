import Foundation
import Darwin

/// Estimates total CPU usage from Mach host processor load counters.
/// This is real system data — the same source Activity Monitor uses.
nonisolated struct CPUUsageSampler {

    private struct Ticks {
        var user: Int32 = 0
        var system: Int32 = 0
        var idle: Int32 = 0
        var nice: Int32 = 0
    }

    private var previous: Ticks?

    mutating func sample() -> Double? {
        var count: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        var info: processor_info_array_t?

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &count,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS, let info else {
            return nil
        }

        var ticks = Ticks()
        let entriesPerCPU = 4 // USER, SYSTEM, IDLE, NICE
        let totalEntries = Int(infoCount)
        var index = 0
        while index + 3 < totalEntries {
            ticks.user += info[index + 0]
            ticks.system += info[index + 1]
            ticks.idle += info[index + 2]
            ticks.nice += info[index + 3]
            index += entriesPerCPU
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        guard let previous else {
            self.previous = ticks
            return nil
        }

        let totalDelta = Double(ticks.user + ticks.system + ticks.idle + ticks.nice)
            - Double(previous.user + previous.system + previous.idle + previous.nice)
        let idleDelta = Double(ticks.idle) - Double(previous.idle)

        self.previous = ticks

        guard totalDelta > 0 else { return nil }

        let usage = 1.0 - idleDelta / totalDelta
        return min(max(usage * 100.0, 0), 100)
    }
}