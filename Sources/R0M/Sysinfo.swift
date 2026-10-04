import Foundation
import Darwin
import IOKit
import IOKit.ps

struct CPUTicks {
    var user: UInt64 = 0
    var system: UInt64 = 0
    var idle: UInt64 = 0
    var nice: UInt64 = 0
    var total: UInt64 { user &+ system &+ idle &+ nice }
    var busy: UInt64 { user &+ system &+ nice }
}

enum CPUProbe {

    static func hostTicks() -> CPUTicks? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { raw in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, raw, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    static func perCoreTicks() -> [CPUTicks] {
        var count: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &infoArray, &infoCount)
        guard kr == KERN_SUCCESS, let infoArray else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoArray), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var result: [CPUTicks] = []
        let stride = Int(CPU_STATE_MAX)
        for core in 0..<Int(count) {
            let base = core * stride
            result.append(CPUTicks(
                user: UInt64(bitPattern: Int64(infoArray[base + Int(CPU_STATE_USER)])),
                system: UInt64(bitPattern: Int64(infoArray[base + Int(CPU_STATE_SYSTEM)])),
                idle: UInt64(bitPattern: Int64(infoArray[base + Int(CPU_STATE_IDLE)])),
                nice: UInt64(bitPattern: Int64(infoArray[base + Int(CPU_STATE_NICE)]))
            ))
        }
        return result
    }
}

enum MemoryPressureLevel: Int {
    case normal = 1, warning = 2, critical = 4
    var label: String {
        switch self { case .normal: return "Normal"; case .warning: return "Warning"; case .critical: return "Critical" }
    }
}

struct MemorySnapshot {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var appMemory: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var usedFraction: Double = 0
    var pressureLevel: MemoryPressureLevel = .normal
    var freePercent: Int? = nil
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
}

enum MemoryProbe {
    static func snapshot() -> MemorySnapshot {
        var snap = MemorySnapshot()
        snap.total = SysctlProbe.uint64("hw.memsize") ?? 0

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let ps = UInt64(pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, raw, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let wired = UInt64(stats.wire_count) * ps
            let compressed = UInt64(stats.compressor_page_count) * ps
            let purgeable = UInt64(stats.purgeable_count) * ps
            let external = UInt64(stats.external_page_count) * ps
            let internalPages = UInt64(stats.internal_page_count) * ps
            let app = internalPages > purgeable ? internalPages - purgeable : internalPages
            snap.wired = wired
            snap.compressed = compressed
            snap.appMemory = app
            snap.cached = purgeable + external
            snap.free = UInt64(stats.free_count) * ps
            snap.used = app + wired + compressed
            if snap.total > 0 { snap.usedFraction = min(1, Double(snap.used) / Double(snap.total)) }
        }

        if let lvl = SysctlProbe.int32("kern.memorystatus_vm_pressure_level"),
           let level = MemoryPressureLevel(rawValue: Int(lvl)) {
            snap.pressureLevel = level
        }
        snap.freePercent = SysctlProbe.int32("kern.memorystatus_level").map(Int.init)

        var xsw = xsw_usage()
        var sz = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &xsw, &sz, nil, 0) == 0 {
            snap.swapTotal = xsw.xsu_total
            snap.swapUsed = xsw.xsu_used
        }
        return snap
    }
}

struct BatterySnapshot {
    var isPresent = false
    var percentage: Int = 0
    var isCharging = false
    var isPluggedIn = false
    var timeToEmptyMin: Int? = nil
    var timeToFullMin: Int? = nil
    var cycleCount: Int? = nil
    var designCapacity: Int? = nil
    var currentMaxCapacity: Int? = nil
    var healthPercent: Double? = nil
    var condition: String? = nil
    var temperatureC: Double? = nil
    var powerSourceState: String? = nil
    var amperageMA: Int? = nil
    var voltageV: Double? = nil
    var systemPowerW: Double? = nil
    var wallPowerInW: Double? = nil
    var adapterWatts: Int? = nil
    var health: String? = nil
}

private extension Dictionary where Key == String, Value == Any {

    func signedInt(_ key: String) -> Int? {
        (self[key] as? NSNumber).map { Int($0.int64Value) }
    }
}

enum BatteryProbe {
    static func snapshot() -> BatterySnapshot {
        var snap = BatterySnapshot()

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for src in list {
                guard let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else { continue }
                snap.isPresent = true
                if let cur = desc[kIOPSCurrentCapacityKey] as? Int { snap.percentage = cur }
                if let charging = desc[kIOPSIsChargingKey] as? Bool { snap.isCharging = charging }
                if let state = desc[kIOPSPowerSourceStateKey] as? String {
                    snap.powerSourceState = state
                    snap.isPluggedIn = (state == kIOPSACPowerValue)
                }
                if let h = desc[kIOPSBatteryHealthKey] as? String { snap.health = h }
                if let tte = desc[kIOPSTimeToEmptyKey] as? Int, tte > 0 { snap.timeToEmptyMin = tte }
                if let ttf = desc[kIOPSTimeToFullChargeKey] as? Int, ttf > 0 { snap.timeToFullMin = ttf }
            }
        }

        if let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any],
           let w = adapter[kIOPSPowerAdapterWattsKey] as? Int, w > 0 {
            snap.adapterWatts = w
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsRef?.takeRetainedValue() as? [String: Any] {

                let nested = props["BatteryData"] as? [String: Any] ?? [:]
                func value(_ key: String) -> Int? { props.signedInt(key) ?? nested.signedInt(key) }
                snap.cycleCount = value("CycleCount")
                snap.designCapacity = value("DesignCapacity")
                let nominal = value("NominalChargeCapacity") ?? value("AppleRawMaxCapacity")
                snap.currentMaxCapacity = nominal
                if let design = snap.designCapacity, let nom = nominal, design > 0 {
                    snap.healthPercent = min(100, Double(nom) / Double(design) * 100)
                }
                if let temp = props.signedInt("Temperature") {

                    let c = Double(temp) / 100.0
                    if c > 0 && c < 100 { snap.temperatureC = c }
                }
                if let amp = props.signedInt("Amperage") { snap.amperageMA = amp }
                if let mv = props.signedInt("Voltage") { snap.voltageV = Double(mv) / 1000.0 }
                if let tele = props["PowerTelemetryData"] as? [String: Any] {
                    if let load = tele.signedInt("SystemLoad"), load > 0 { snap.systemPowerW = Double(load) / 1000.0 }
                    if let wall = tele.signedInt("SystemPowerIn"), wall > 0 { snap.wallPowerInW = Double(wall) / 1000.0 }
                }
                if let perm = props.signedInt("PermanentFailureStatus") {
                    snap.condition = perm == 0 ? "Normal" : "Service Recommended"
                }
                if let bh = props["BatteryHealthCondition"] as? String { snap.condition = bh }

                if snap.condition == nil, let h = snap.healthPercent {
                    snap.condition = h >= 80 ? "Normal" : "Service Recommended"
                }
            }
        }
        return snap
    }
}

struct NetTotals {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var packetsIn: UInt64 = 0
    var packetsOut: UInt64 = 0
}

enum NetworkProbe {

    static func totals() -> NetTotals {
        var totals = NetTotals()
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else { return totals }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return totals }

        buf.withUnsafeBytes { raw in
            var off = 0
            while off + MemoryLayout<if_msghdr>.size <= len {
                var hdr = if_msghdr()
                withUnsafeMutableBytes(of: &hdr) { $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: raw[off..<(off + MemoryLayout<if_msghdr>.size)])) }
                let msgLen = Int(hdr.ifm_msglen)
                guard msgLen > 0 else { break }
                if Int32(hdr.ifm_type) == RTM_IFINFO2, off + MemoryLayout<if_msghdr2>.size <= len {
                    var m = if_msghdr2()
                    withUnsafeMutableBytes(of: &m) { $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: raw[off..<(off + MemoryLayout<if_msghdr2>.size)])) }
                    var nameBuf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(m.ifm_index), &nameBuf) != nil,
                       isPhysical(String(cString: nameBuf)),
                       (Int32(m.ifm_flags) & IFF_LOOPBACK) == 0 {
                        totals.bytesIn &+= m.ifm_data.ifi_ibytes
                        totals.bytesOut &+= m.ifm_data.ifi_obytes
                        totals.packetsIn &+= m.ifm_data.ifi_ipackets
                        totals.packetsOut &+= m.ifm_data.ifi_opackets
                    }
                }
                off += msgLen
            }
        }
        return totals
    }

    private static func isPhysical(_ name: String) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("pdp_ip")
    }

    static func primaryInterface() -> (name: String, ipv4: String?)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return nil }
        defer { freeifaddrs(ifaddrPtr) }
        var ptr = ifaddrPtr
        var result: (String, String?)?
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            let flags = Int32(cur.pointee.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0, (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0 else { continue }
            guard let addr = cur.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            result = (name, String(cString: host))
            break
        }
        return result
    }
}

struct DiskSnapshot {
    var total: UInt64 = 0
    var available: UInt64 = 0
    var used: UInt64 { total > available ? total - available : 0 }
}

enum DiskProbe {
    static func snapshot(path: String = "/") -> DiskSnapshot {
        var snap = DiskSnapshot()
        let url = URL(fileURLWithPath: path)
        if let vals = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            snap.total = UInt64(vals.volumeTotalCapacity ?? 0)
            snap.available = UInt64(vals.volumeAvailableCapacityForImportantUsage ?? 0)
        }
        return snap
    }
}

enum SysctlProbe {
    static func uint64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
    static func int32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }
    static func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }
}

struct HostSnapshot {
    var hostName: String = ""
    var modelIdentifier: String = ""
    var chip: String = ""
    var coreCount: Int = 0
    var performanceCores: Int?
    var efficiencyCores: Int?
    var gpuCores: Int?
    var osVersion: String = ""
    var osBuild: String = ""
    var kernelVersion: String = ""
    var bootTime: Date?
    var uptime: TimeInterval = 0
    var thermalState: ProcessInfo.ThermalState = .nominal
    var lowPowerMode = false
}

enum HostProbe {

    private static let fixed: HostSnapshot = {
        var s = HostSnapshot()
        s.hostName = Host.current().localizedName ?? (SysctlProbe.string("kern.hostname") ?? "Mac")
        s.modelIdentifier = SysctlProbe.string("hw.model") ?? "Unknown"
        s.chip = SysctlProbe.string("machdep.cpu.brand_string") ?? "Apple Silicon"
        s.coreCount = Int(SysctlProbe.int32("hw.ncpu") ?? 0)
        s.performanceCores = SysctlProbe.int32("hw.perflevel0.logicalcpu").map(Int.init)
        s.efficiencyCores = SysctlProbe.int32("hw.perflevel1.logicalcpu").map(Int.init)
        s.gpuCores = GPUProbe.coreCount()
        let os = ProcessInfo.processInfo.operatingSystemVersion
        s.osVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        s.osBuild = SysctlProbe.string("kern.osversion") ?? ""
        s.kernelVersion = SysctlProbe.string("kern.version")?.split(separator: ";").first.map(String.init) ?? ""
        s.bootTime = SysctlProbe.bootTime()
        return s
    }()

    static func snapshot() -> HostSnapshot {
        var s = fixed
        if let bt = s.bootTime { s.uptime = Date().timeIntervalSince(bt) }
        s.thermalState = ProcessInfo.processInfo.thermalState
        s.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        return s
    }
}
