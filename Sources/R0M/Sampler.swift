import Foundation
import SwiftUI
import Combine

struct HistoryPoint: Identifiable {
    let id = UUID()
    let t: Date
    let value: Double
}

@MainActor
final class Sampler: ObservableObject {

    @Published var host = HostProbe.snapshot()
    @Published var memory = MemoryProbe.snapshot()
    @Published var battery = BatteryProbe.snapshot()
    @Published var disk = DiskProbe.snapshot()
    @Published var thermal = ThermalSnapshot()

    @Published var cpuUsage: Double = 0
    @Published var perCoreUsage: [Double] = []
    @Published var netInRate: Double = 0
    @Published var netOutRate: Double = 0
    @Published var netSessionIn: UInt64 = 0
    @Published var netSessionOut: UInt64 = 0
    @Published var primaryInterface: String = "—"
    @Published var localIP: String? = nil

    @Published var wattage: Double = 0
    @Published var isCharging: Bool = false
    @Published var wattHistory: [HistoryPoint] = []
    @Published var sleepBlockers: [SleepBlocker] = []

    @Published var gpuUsage: Double = 0
    @Published var gpuAvailable = false
    @Published var gpuHistory: [HistoryPoint] = []
    @Published var diskReadRate: Double = 0
    @Published var diskWriteRate: Double = 0
    @Published var diskReadHistory: [HistoryPoint] = []
    @Published var diskWriteHistory: [HistoryPoint] = []
    @Published var wifi: WiFiSnapshot? = nil
    @Published var btDevices: [BTDevice] = []
    @Published var schedule = PowerScheduleState()

    @Published var cpuHistory: [HistoryPoint] = []
    @Published var memHistory: [HistoryPoint] = []
    @Published var netInHistory: [HistoryPoint] = []
    @Published var netOutHistory: [HistoryPoint] = []
    @Published var batteryTempHistory: [HistoryPoint] = []
    @Published var cpuTempHistory: [HistoryPoint] = []

    @Published var powerHistory = PowerHistory()
    @Published var thermalEvents: [ThermalEvent] = []
    @Published var topProcesses: [ProcInfo] = []
    @Published var processSort: ProcessSort = .cpu { didSet { refreshProcesses() } }
    @Published var hardware = HardwareDetails()
    @Published var volumes: [VolumeInfo] = []

    @Published var cleanItems: [CleanItem] = []
    @Published var cleanScanning = false
    @Published var cleanHasScanned = false
    @Published var trashBytes: UInt64? = nil
    @Published var lastCleanMessage: String? = nil
    @Published var lastCleanOK = true

    @Published var sampleInterval: Double = {
        let v = UserDefaults.standard.double(forKey: "sampleInterval")
        return [1.0, 2.0, 5.0].contains(v) ? v : 2.0
    }() { didSet { UserDefaults.standard.set(sampleInterval, forKey: "sampleInterval"); restartTimer() } }
    @Published var showTempInMenuBar: Bool = UserDefaults.standard.bool(forKey: "showTempInMenuBar") {
        didSet { UserDefaults.standard.set(showTempInMenuBar, forKey: "showTempInMenuBar") }
    }

    var batteryTemp: Double? { battery.temperatureC ?? thermal.battery }

    var detailVisible = false { didSet { if detailVisible && !oldValue { refreshSlowProbes() } } }

    enum ProcessSort: String, CaseIterable, Identifiable {
        case cpu = "CPU", memory = "Memory"
        var id: String { rawValue }
    }
    struct ThermalEvent: Identifiable { let id = UUID(); let t: Date; let state: ProcessInfo.ThermalState }

    private let maxHistory = 90
    private var prevCPU: CPUTicks?
    private var prevPerCore: [CPUTicks] = []
    private var prevNet: NetTotals?
    private var prevNetTime: Date?
    private var netBaseline: NetTotals?
    private var prevDiskIO: DiskIOTotals?
    private var prevDiskTime: Date?
    private var lastThermal: ProcessInfo.ThermalState?
    private var started = false
    private var lastSlowRefresh = Date.distantPast
    private var lastBluetoothRefresh = Date.distantPast
    private var timerCancellable: AnyCancellable?

    func start() {
        guard !started else { return }
        started = true

        prevCPU = CPUProbe.hostTicks()
        prevPerCore = CPUProbe.perCoreTicks()
        prevNet = NetworkProbe.totals()
        netBaseline = prevNet
        prevNetTime = Date()
        prevDiskIO = DiskIOProbe.totals()
        prevDiskTime = Date()
        recordThermal(host.thermalState)
        tick()
        refreshPowerHistory()
        refreshSchedule()
        refreshStaticDetails()
        restartTimer()
    }

    private func restartTimer() {
        guard started else { return }
        timerCancellable = Timer.publish(every: sampleInterval, tolerance: sampleInterval * 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
    }

    func refreshStaticDetails() {
        Task.detached(priority: .utility) {
            let hw = HardwareProbe.collect()
            let vols = VolumeProbe.all()
            await MainActor.run { self.hardware = hw; self.volumes = vols }
        }
    }

    func refreshWiFiBluetooth() {
        wifi = WiFiProbe.snapshot()
        lastBluetoothRefresh = Date()
        Task.detached(priority: .utility) {
            let devices = BluetoothProbe.devices()
            await MainActor.run { self.btDevices = devices }
        }
    }

    func refreshSchedule() {
        Task.detached(priority: .utility) {
            let s = PowerScheduleProbe.current()
            await MainActor.run { self.schedule = s }
        }
    }

    func tick() {
        let now = Date()
        host = HostProbe.snapshot()
        memory = MemoryProbe.snapshot()
        battery = BatteryProbe.snapshot()
        disk = DiskProbe.snapshot()
        thermal = ThermalSensors.shared.read()

        if let cur = CPUProbe.hostTicks(), let prev = prevCPU {
            let totalDelta = Double(cur.total &- prev.total)
            let busyDelta = Double(cur.busy &- prev.busy)
            if totalDelta > 0 { cpuUsage = max(0, min(1, busyDelta / totalDelta)) }
            prevCPU = cur
        }

        let curCores = CPUProbe.perCoreTicks()
        if !curCores.isEmpty, curCores.count == prevPerCore.count {
            perCoreUsage = zip(curCores, prevPerCore).map { cur, prev in
                let td = Double(cur.total &- prev.total)
                let bd = Double(cur.busy &- prev.busy)
                return td > 0 ? max(0, min(1, bd / td)) : 0
            }
        } else if perCoreUsage.isEmpty {
            perCoreUsage = Array(repeating: 0, count: curCores.count)
        }
        if !curCores.isEmpty { prevPerCore = curCores }

        let curNet = NetworkProbe.totals()
        if let prev = prevNet, let pt = prevNetTime {
            let dt = now.timeIntervalSince(pt)

            if dt >= 0.5 {
                netInRate = curNet.bytesIn >= prev.bytesIn ? Double(curNet.bytesIn - prev.bytesIn) / dt : 0
                netOutRate = curNet.bytesOut >= prev.bytesOut ? Double(curNet.bytesOut - prev.bytesOut) / dt : 0
            }
        }
        if let base = netBaseline {
            netSessionIn = curNet.bytesIn >= base.bytesIn ? curNet.bytesIn - base.bytesIn : 0
            netSessionOut = curNet.bytesOut >= base.bytesOut ? curNet.bytesOut - base.bytesOut : 0
        }
        if prevNetTime.map({ now.timeIntervalSince($0) >= 0.5 }) ?? true {
            prevNet = curNet
            prevNetTime = now
        }
        if let p = NetworkProbe.primaryInterface() {
            primaryInterface = p.name
            localIP = p.ipv4
        }

        if let g = GPUProbe.utilization() {
            gpuAvailable = true
            gpuUsage = g
        }

        let curDisk = DiskIOProbe.totals()
        if let prev = prevDiskIO, let pt = prevDiskTime {
            let dt = now.timeIntervalSince(pt)
            if dt >= 0.5 {
                diskReadRate = curDisk.read >= prev.read ? Double(curDisk.read - prev.read) / dt : 0
                diskWriteRate = curDisk.write >= prev.write ? Double(curDisk.write - prev.write) / dt : 0
            }
        }
        if prevDiskTime.map({ now.timeIntervalSince($0) >= 0.5 }) ?? true {
            prevDiskIO = curDisk
            prevDiskTime = now
        }

        isCharging = battery.isCharging
        let flow: Double? = {
            guard let ma = battery.amperageMA, let v = battery.voltageV else { return nil }
            return abs(Double(ma)) / 1000.0 * v
        }()
        if isCharging { wattage = flow ?? 0 }
        else { wattage = battery.systemPowerW ?? flow ?? 0 }

        recordThermal(host.thermalState)

        append(&cpuHistory, HistoryPoint(t: now, value: cpuUsage * 100))
        append(&memHistory, HistoryPoint(t: now, value: memory.usedFraction * 100))
        append(&netInHistory, HistoryPoint(t: now, value: netInRate))
        append(&netOutHistory, HistoryPoint(t: now, value: netOutRate))
        if let temp = batteryTemp { append(&batteryTempHistory, HistoryPoint(t: now, value: temp)) }
        if let cpuT = thermal.cpuAverage { append(&cpuTempHistory, HistoryPoint(t: now, value: cpuT)) }
        if wattage > 0 { append(&wattHistory, HistoryPoint(t: now, value: wattage)) }
        if gpuAvailable { append(&gpuHistory, HistoryPoint(t: now, value: gpuUsage * 100)) }
        append(&diskReadHistory, HistoryPoint(t: now, value: diskReadRate))
        append(&diskWriteHistory, HistoryPoint(t: now, value: diskWriteRate))

        if detailVisible, now.timeIntervalSince(lastSlowRefresh) >= 6 { refreshSlowProbes() }
    }

    func refreshSlowProbes() {
        lastSlowRefresh = Date()
        refreshProcesses()
        refreshSleepBlockers()
        wifi = WiFiProbe.snapshot()
        if Date().timeIntervalSince(lastBluetoothRefresh) >= 30 { refreshWiFiBluetooth() }
    }

    func applySchedule(onDays: [String], onTime: String, offDays: [String], offTime: String, offType: String) -> (Bool, String) {
        let result = PowerScheduleProbe.apply(onDays: onDays, onTime: onTime, offDays: offDays, offTime: offTime, offType: offType)
        refreshSchedule()
        return result
    }

    func cancelSchedule() -> (Bool, String) {
        let result = PowerScheduleProbe.cancel()
        refreshSchedule()
        return result
    }

    func refreshSleepBlockers() {
        Task.detached(priority: .utility) {
            let blockers = SleepBlockerProbe.collect()
            await MainActor.run { self.sleepBlockers = blockers }
        }
    }

    func refreshProcesses() {
        let sort = processSort
        Task.detached(priority: .utility) {
            let procs = ProcessProbe.top(by: sort == .cpu ? "cpu" : "mem", limit: 8)
            await MainActor.run { self.topProcesses = procs }
        }
    }

    private func append(_ buffer: inout [HistoryPoint], _ point: HistoryPoint) {
        buffer.append(point)
        if buffer.count > maxHistory { buffer.removeFirst(buffer.count - maxHistory) }
    }

    private func recordThermal(_ state: ProcessInfo.ThermalState) {
        if lastThermal != state {
            lastThermal = state
            thermalEvents.insert(ThermalEvent(t: Date(), state: state), at: 0)
            if thermalEvents.count > 50 { thermalEvents.removeLast(thermalEvents.count - 50) }
        }
    }

    func refreshPowerHistory() {
        Task.detached(priority: .utility) {
            let h = PowerHistoryProbe.collect()
            await MainActor.run { self.powerHistory = h }
        }
    }

    func scanCleaner() {
        guard !cleanScanning else { return }
        cleanScanning = true
        Task.detached(priority: .utility) {
            let items = Cleaner.scan()
            let trash = Cleaner.trashSize()
            await MainActor.run {
                self.cleanItems = items
                self.trashBytes = trash
                self.cleanScanning = false
                self.cleanHasScanned = true
            }
        }
    }

    func clean(_ items: [CleanItem], mode: CleanMode) {
        cleanScanning = true
        Task.detached(priority: .userInitiated) {
            let r = Cleaner.clear(items, mode: mode)
            await MainActor.run {
                let size = Formatters.fileBytes(r.reclaimed)
                var msg: String
                if r.wentToTrash {
                    msg = "Moved \(r.removed) item(s) (\(size)) to the Trash. Empty the Trash to actually free the space."
                } else {
                    msg = "Removed \(r.removed) item(s) · freed \(size)."
                }
                if !r.skipped.isEmpty {
                    msg += " Skipped \(r.skipped.count): " + r.skipped.prefix(2).joined(separator: "; ")
                }
                self.lastCleanMessage = msg
                self.lastCleanOK = r.skipped.isEmpty
                self.cleanScanning = false
                self.scanCleaner()
            }
        }
    }

    func runCleanerAction(_ action: @escaping @Sendable () -> (Bool, String)) {
        Task.detached(priority: .userInitiated) {
            let r = action()
            await MainActor.run {
                self.lastCleanMessage = r.1
                self.lastCleanOK = r.0
                self.scanCleaner()
            }
        }
    }
}

enum Formatters {

    static func bytes(_ v: UInt64) -> String { format(v, .memory) }

    static func fileBytes(_ v: UInt64) -> String { format(v, .file) }

    private static func format(_ v: UInt64, _ style: ByteCountFormatter.CountStyle) -> String {
        let bcf = ByteCountFormatter()
        bcf.countStyle = style
        bcf.allowedUnits = [.useTB, .useGB, .useMB, .useKB]
        bcf.allowsNonnumericFormatting = false
        return bcf.string(fromByteCount: Int64(clamping: v))
    }
    static func rate(_ bytesPerSec: Double) -> String {
        let v = max(0, bytesPerSec)
        if v < 1024 { return String(format: "%.0f B/s", v) }
        if v < 1024 * 1024 { return String(format: "%.1f KB/s", v / 1024) }
        return String(format: "%.2f MB/s", v / (1024 * 1024))
    }
    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
    static func minutes(_ m: Int) -> String {
        let h = m / 60, mm = m % 60
        return h > 0 ? "\(h)h \(mm)m" : "\(mm)m"
    }
    static let dateTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM, HH:mm"; return f
    }()
    static let timeOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    var tint: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}
