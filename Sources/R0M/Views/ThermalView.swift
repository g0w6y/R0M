import SwiftUI
import Charts

struct ThermalView: View {
    @EnvironmentObject var sampler: Sampler
    private let cols = [GridItem(.adaptive(minimum: 165), spacing: UI.gridSpacing)]

    var body: some View {
        let t = sampler.thermal
        SectionScaffold(title: "Thermal", subtitle: "Real sensor temperatures and macOS thermal pressure") {
            LazyVGrid(columns: cols, spacing: UI.gridSpacing) {
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(sampler.host.thermalState.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sampler.host.thermalState.label).font(.system(size: 20, weight: .bold))
                            Text("Thermal pressure").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
                if let v = t.cpuAverage {
                    StatTile(label: "CPU / SoC", value: deg(v), sub: t.cpuMax.map { "hottest " + deg($0) }, systemImage: "cpu", accent: tempTint(v))
                }
                if let v = t.ssd { StatTile(label: "SSD", value: deg(v), systemImage: "internaldrive", accent: tempTint(v)) }
                if let v = sampler.batteryTemp { StatTile(label: "Battery", value: deg(v), systemImage: "battery.100percent", accent: tempTint(v)) }
                if let v = t.board { StatTile(label: "Board", value: deg(v), systemImage: "square.grid.3x3", accent: tempTint(v)) }
                StatTile(label: "Low power mode", value: sampler.host.lowPowerMode ? "On" : "Off", systemImage: "leaf", accent: sampler.host.lowPowerMode ? .green : .gray)
            }

            if !t.isAvailable {
                Card { Label("Temperature sensors aren't exposed on this Mac, so only thermal pressure is shown.", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(.secondary) }
            }

            if sampler.cpuTempHistory.count > 1 {
                Card(title: "CPU temperature — last 3 min", systemImage: "thermometer.medium", accent: .orange) {
                    LineSeriesChart(points: sampler.cpuTempHistory, tint: .orange, unit: "°", height: 150)
                }
            }
            if sampler.batteryTempHistory.count > 1 {
                Card(title: "Battery temperature — last 3 min", systemImage: "thermometer", accent: .yellow) {
                    LineSeriesChart(points: sampler.batteryTempHistory, tint: .yellow, unit: "°")
                }
            }

            Card(title: "Thermal pressure changes (this session)", systemImage: "clock.badge.exclamationmark", accent: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    if sampler.thermalEvents.count <= 1 {
                        Label("Stayed \(sampler.host.thermalState.label.lowercased()) since R0M started.", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12)).foregroundStyle(.green)
                    }
                    ForEach(sampler.thermalEvents) { e in
                        HStack {
                            Circle().fill(e.state.tint).frame(width: 9, height: 9)
                            Text(e.state.label).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(Formatters.timeOnly.string(from: e.t)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    Text("Temperatures come from the SoC's own PMU, NAND and battery-gauge sensors (no root needed). They're the same sensors macOS uses to throttle. R0M only records history while it is running.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 4)
                }
            }
        }
    }
    private func deg(_ v: Double) -> String { String(format: "%.0f °C", v) }
}
