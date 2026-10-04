import SwiftUI
import Charts
import AppKit

struct OverviewView: View {
    @EnvironmentObject var sampler: Sampler
    private let cols = [GridItem(.adaptive(minimum: 165), spacing: UI.gridSpacing)]

    var body: some View {
        SectionScaffold(title: "Overview", subtitle: healthLine) {
            LazyVGrid(columns: cols, spacing: UI.gridSpacing) {
                StatTile(label: "CPU Load", value: "\(Int(sampler.cpuUsage * 100))%", sub: "\(sampler.host.coreCount) cores", systemImage: "cpu", accent: .blue)
                StatTile(label: "Memory", value: "\(Int(sampler.memory.usedFraction * 100))%", sub: "\(Formatters.bytes(sampler.memory.used)) of \(Formatters.bytes(sampler.memory.total))", systemImage: "memorychip", accent: .purple)
                StatTile(label: "Battery", value: sampler.battery.isPresent ? "\(sampler.battery.percentage)%" : "—", sub: batterySub, systemImage: "battery.100percent", accent: .green)
                StatTile(label: "Thermal", value: sampler.thermal.cpuAverage.map { String(format: "%.0f °C", $0) } ?? sampler.host.thermalState.label, sub: sampler.thermal.cpuAverage == nil ? nil : sampler.host.thermalState.label, systemImage: "thermometer.medium", accent: sampler.thermal.cpuAverage.map(tempTint) ?? sampler.host.thermalState.tint)
                StatTile(label: "Download", value: Formatters.rate(sampler.netInRate), systemImage: "arrow.down.circle", accent: .teal)
                StatTile(label: "Upload", value: Formatters.rate(sampler.netOutRate), systemImage: "arrow.up.circle", accent: .teal)
                StatTile(label: "Disk Free", value: Formatters.fileBytes(sampler.disk.available), sub: "of \(Formatters.fileBytes(sampler.disk.total))", systemImage: "internaldrive", accent: .indigo)
                StatTile(label: "Uptime", value: Formatters.duration(sampler.host.uptime), systemImage: "clock", accent: .pink)
            }

            HStack(alignment: .top, spacing: UI.gridSpacing) {
                Card(title: "CPU — last 3 min", systemImage: "cpu", accent: .blue) {
                    PercentAreaChart(points: sampler.cpuHistory, tint: .blue)
                }
                Card(title: "Memory used — last 3 min", systemImage: "memorychip", accent: .purple) {
                    PercentAreaChart(points: sampler.memHistory, tint: .purple)
                }
            }

            Card(title: "Top processes", systemImage: "list.bullet", accent: .blue) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $sampler.processSort) {
                        ForEach(Sampler.ProcessSort.allCases) { Text("By \($0.rawValue)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                    ProcessTable(processes: sampler.topProcesses)
                }
            }
        }
    }

    private var healthLine: String {
        var issues: [String] = []
        if sampler.memory.pressureLevel != .normal { issues.append("memory pressure \(sampler.memory.pressureLevel.label.lowercased())") }
        if sampler.host.thermalState != .nominal { issues.append("thermal \(sampler.host.thermalState.label.lowercased())") }
        if sampler.disk.total > 0 && Double(sampler.disk.available) / Double(sampler.disk.total) < 0.1 { issues.append("low disk space") }
        if let h = sampler.battery.healthPercent, h < 80 { issues.append("battery health \(Int(h))%") }
        if issues.isEmpty { return "All systems nominal · \(sampler.host.chip)" }
        return "Attention: " + issues.joined(separator: ", ")
    }

    private var batterySub: String {
        guard sampler.battery.isPresent else { return "No battery" }
        if sampler.battery.isCharging { return "Charging" }
        if sampler.battery.isPluggedIn { return "Plugged in" }
        if let m = sampler.battery.timeToEmptyMin { return "\(Formatters.minutes(m)) left" }
        return "On battery"
    }
}

struct ProcessTable: View {
    let processes: [ProcInfo]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Process").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("CPU").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                Text("MEM").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
            }
            .padding(.bottom, 6)
            if processes.isEmpty {
                Text("Sampling…").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                ForEach(processes) { p in
                    HStack {
                        Text(p.command).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(String(format: "%.1f%%", p.cpu)).font(.system(size: 12)).monospacedDigit().frame(width: 60, alignment: .trailing)
                            .foregroundStyle(p.cpu > 50 ? .orange : .primary)
                        Text(String(format: "%.1f%%", p.mem)).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    Divider().opacity(p.id == processes.last?.id ? 0 : 0.4)
                }
            }
        }
    }
}
