import Foundation
import IOKit

struct DiskIOTotals {
    var read: UInt64 = 0
    var write: UInt64 = 0
    var readOps: UInt64 = 0
    var writeOps: UInt64 = 0
}

enum DiskIOProbe {
    static func totals() -> DiskIOTotals {
        var totals = DiskIOTotals()
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return totals
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let r = stats["Bytes (Read)"] as? Int, r >= 0 { totals.read &+= UInt64(r) }
                if let w = stats["Bytes (Write)"] as? Int, w >= 0 { totals.write &+= UInt64(w) }
                if let r = stats["Operations (Read)"] as? Int, r >= 0 { totals.readOps &+= UInt64(r) }
                if let w = stats["Operations (Write)"] as? Int, w >= 0 { totals.writeOps &+= UInt64(w) }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return totals
    }
}
