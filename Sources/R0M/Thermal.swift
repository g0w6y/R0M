import Foundation
import IOKit

struct ThermalSnapshot {
    var cpuAverage: Double?
    var cpuMax: Double?
    var dieSensorCount = 0
    var ssd: Double?
    var battery: Double?
    var board: Double?
    var isAvailable = false
}

final class ThermalSensors {
    static let shared = ThermalSensors()

    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
    private typealias SetMatchFn = @convention(c) (CFTypeRef, CFDictionary) -> Int32
    private typealias CopyServicesFn = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?
    private typealias CopyPropFn = @convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?
    private typealias CopyEventFn = @convention(c) (CFTypeRef, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias FloatFn = @convention(c) (CFTypeRef, Int32) -> Double

    private struct Sensor { let service: CFTypeRef; let name: String }

    private var sensors: [Sensor] = []
    private var client: CFTypeRef?
    private var copyEvent: CopyEventFn?
    private var floatValue: FloatFn?

    private init() {
        let h = dlopen(nil, RTLD_NOW)
        guard let c = dlsym(h, "IOHIDEventSystemClientCreate"),
              let m = dlsym(h, "IOHIDEventSystemClientSetMatching"),
              let s = dlsym(h, "IOHIDEventSystemClientCopyServices"),
              let p = dlsym(h, "IOHIDServiceClientCopyProperty"),
              let e = dlsym(h, "IOHIDServiceClientCopyEvent"),
              let f = dlsym(h, "IOHIDEventGetFloatValue") else { return }
        let create = unsafeBitCast(c, to: CreateFn.self)
        let setMatching = unsafeBitCast(m, to: SetMatchFn.self)
        let copyServices = unsafeBitCast(s, to: CopyServicesFn.self)
        let copyProp = unsafeBitCast(p, to: CopyPropFn.self)
        copyEvent = unsafeBitCast(e, to: CopyEventFn.self)
        floatValue = unsafeBitCast(f, to: FloatFn.self)

        guard let cl = create(kCFAllocatorDefault)?.takeRetainedValue() else { return }
        client = cl

        _ = setMatching(cl, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let list = copyServices(cl)?.takeRetainedValue() as [AnyObject]? else { return }
        for svc in list {
            let ref = svc as CFTypeRef
            let name = copyProp(ref, "Product" as CFString)?.takeRetainedValue() as? String ?? ""
            sensors.append(Sensor(service: ref, name: name))
        }
    }

    var sensorNames: [String] { sensors.map(\.name) }

    func read() -> ThermalSnapshot {
        var snap = ThermalSnapshot()
        guard let copyEvent, let floatValue, !sensors.isEmpty else { return snap }

        var die: [Double] = [], board: [Double] = [], batt: [Double] = [], nand: [Double] = []
        for sensor in sensors {
            guard let ev = copyEvent(sensor.service, 15, 0, 0)?.takeRetainedValue() else { continue }
            let t = floatValue(ev, 15 << 16)

            guard t > 0, t < 130 else { continue }
            let n = sensor.name.lowercased()
            if n.contains("tdie") || n.contains("mtr temp sensor") { die.append(t) }
            else if n.contains("tdev") { board.append(t) }
            else if n.contains("gas gauge") || n.contains("battery") { batt.append(t) }
            else if n.contains("nand") { nand.append(t) }
        }
        snap.isAvailable = !(die.isEmpty && board.isEmpty && batt.isEmpty && nand.isEmpty)
        snap.dieSensorCount = die.count
        if !die.isEmpty { snap.cpuAverage = die.reduce(0, +) / Double(die.count); snap.cpuMax = die.max() }
        if !board.isEmpty { snap.board = board.reduce(0, +) / Double(board.count) }
        if !batt.isEmpty { snap.battery = batt.reduce(0, +) / Double(batt.count) }
        if !nand.isEmpty { snap.ssd = nand.max() }
        return snap
    }
}
