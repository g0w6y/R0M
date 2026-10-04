import Foundation

enum Diagnose {
    static func printReport() {
        print(textReport(includeSerial: false))
    }

    static func textReport(includeSerial: Bool) -> String {
        let host = HostProbe.snapshot()
        let mem = MemoryProbe.snapshot()
        let bat = BatteryProbe.snapshot()
        let disk = DiskProbe.snapshot()
        let therm = ThermalSensors.shared.read()
        let hw = HardwareProbe.collect()
        var l: [String] = []
        func add(_ k: String, _ v: String) { l.append("\(k.padding(toLength: 22, withPad: " ", startingAt: 0)) \(v)") }

        l.append("R0M \(AppInfo.version) — system report")
        l.append(String(repeating: "—", count: 44))
        add("Model", [hw.machineName, host.modelIdentifier].filter { !$0.isEmpty }.joined(separator: " · "))
        if includeSerial, !hw.serialNumber.isEmpty { add("Serial", hw.serialNumber) }
        add("Chip", host.chip)
        add("Cores", "\(host.coreCount) (\(host.performanceCores ?? 0)P + \(host.efficiencyCores ?? 0)E), GPU \(host.gpuCores.map(String.init) ?? "?") cores")
        add("Memory", Formatters.bytes(mem.total))
        add("OS", "\(host.osVersion) (\(host.osBuild))")
        add("Uptime", Formatters.duration(host.uptime))
        l.append("")
        add("Memory used", "\(Formatters.bytes(mem.used)) — pressure \(mem.pressureLevel.label)")
        add("  app / wired / comp.", "\(Formatters.bytes(mem.appMemory)) / \(Formatters.bytes(mem.wired)) / \(Formatters.bytes(mem.compressed))")
        add("  swap", "\(Formatters.bytes(mem.swapUsed)) of \(Formatters.bytes(mem.swapTotal))")
        l.append("")
        add("Thermal state", host.thermalState.label)
        if therm.isAvailable {
            add("CPU die avg / max", "\(fmt(therm.cpuAverage)) / \(fmt(therm.cpuMax)) (\(therm.dieSensorCount) sensors)")
            add("SSD / battery", "\(fmt(therm.ssd)) / \(fmt(therm.battery))")
        } else {
            add("Temperatures", "sensors unavailable")
        }
        l.append("")
        if bat.isPresent {
            add("Battery", "\(bat.percentage)% — \(bat.isCharging ? "charging" : (bat.isPluggedIn ? "plugged in" : "on battery"))")
            add("  health", "\(bat.healthPercent.map { String(format: "%.1f%%", $0) } ?? "?") max capacity, \(bat.cycleCount.map(String.init) ?? "?") cycles, \(bat.health ?? bat.condition ?? "?")")
            add("  capacity", "\(bat.currentMaxCapacity.map(String.init) ?? "?") / \(bat.designCapacity.map(String.init) ?? "?") mAh design")
            add("  amperage / voltage", "\(bat.amperageMA.map(String.init) ?? "?") mA / \(bat.voltageV.map { String(format: "%.2f V", $0) } ?? "?")")
            add("  system power", bat.systemPowerW.map { String(format: "%.1f W", $0) } ?? "n/a")
            add("  charger", bat.adapterWatts.map { "\($0) W adapter" } ?? "none")
        } else {
            add("Battery", "none")
        }
        l.append("")
        add("Startup disk", "\(Formatters.fileBytes(disk.available)) free of \(Formatters.fileBytes(disk.total))")
        if !hw.ssdModel.isEmpty { add("  SSD", "\(hw.ssdModel) \(hw.ssdSize) — SMART \(hw.ssdSMART)") }
        for d in hw.displays { add("Display", "\(d.name) \(d.resolution)") }
        l.append("")
        add("Sensors seen", "\(ThermalSensors.shared.sensorNames.count)")
        let names = Dictionary(grouping: ThermalSensors.shared.sensorNames.map { $0.filter { !$0.isNumber } }, by: { $0 })
        for (k, v) in names.sorted(by: { $0.key < $1.key }) { add("  " + k, "×\(v.count)") }
        return l.joined(separator: "\n")
    }

    private static func fmt(_ v: Double?) -> String { v.map { String(format: "%.1f°C", $0) } ?? "—" }
}

enum AppInfo {
    static let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
}
