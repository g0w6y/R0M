import Foundation
import IOKit

enum GPUProbe {

    static func utilization() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        var best: Double? = nil
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let perf = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                let util = (perf["Device Utilization %"] as? Int)
                    ?? (perf["GPU Activity(%)"] as? Int)
                    ?? (perf["Renderer Utilization %"] as? Int)
                if let u = util { best = max(best ?? 0, Double(u) / 100.0) }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return best
    }

    static func coreCount() -> Int? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        var found: Int?
        while service != 0 {
            if let v = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                found = max(found ?? 0, v)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return found
    }
}
