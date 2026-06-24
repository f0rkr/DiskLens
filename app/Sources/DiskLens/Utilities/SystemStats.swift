import Foundation
import Darwin

/// System-wide CPU and memory usage, sampled via Mach APIs — no dependencies.
/// CPU is a fraction of busy time between two samples, so use a `Sampler`
/// (it remembers the previous tick counts).
struct SystemStats {
    var cpuBusy: Double = 0          // 0...1 of CPU busy since the previous sample
    var memUsed: Int64 = 0
    var memTotal: Int64 = 0
    var memFrac: Double { memTotal > 0 ? Double(memUsed) / Double(memTotal) : 0 }

    final class Sampler {
        private var prev: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

        func sample() -> SystemStats {
            var s = SystemStats()
            s.cpuBusy = cpu()
            let m = memory()
            s.memUsed = m.used
            s.memTotal = m.total
            return s
        }

        private func cpu() -> Double {
            var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
            var info = host_cpu_load_info_data_t()
            let kr = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics(mach_host_self(), host_flavor_t(HOST_CPU_LOAD_INFO), $0, &count)
                }
            }
            guard kr == KERN_SUCCESS else { return 0 }
            let user = info.cpu_ticks.0, system = info.cpu_ticks.1
            let idle = info.cpu_ticks.2, nice = info.cpu_ticks.3
            defer { prev = (user, system, idle, nice) }
            guard let p = prev else { return 0 }   // first sample: no delta yet
            let busy = Double(user &- p.user) + Double(system &- p.system) + Double(nice &- p.nice)
            let total = busy + Double(idle &- p.idle)
            return total > 0 ? max(0, min(1, busy / total)) : 0
        }

        private func memory() -> (used: Int64, total: Int64) {
            let total = Int64(ProcessInfo.processInfo.physicalMemory)
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
            var info = vm_statistics64_data_t()
            let kr = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), host_flavor_t(HOST_VM_INFO64), $0, &count)
                }
            }
            guard kr == KERN_SUCCESS else { return (0, total) }
            var pageSize: vm_size_t = 0
            host_page_size(mach_host_self(), &pageSize)
            let ps = Int64(pageSize)
            // Activity-Monitor-style "memory used": app (active) + wired + compressed.
            let used = (Int64(info.active_count) + Int64(info.wire_count) + Int64(info.compressor_page_count)) * ps
            return (min(used, total), total)
        }
    }
}
