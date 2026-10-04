import SwiftUI
import Charts
import AppKit

struct BatteryView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        let b = sampler.battery
        SectionScaffold(title: "Battery", subtitle: b.isPresent ? "Health & charge" : "No battery detected on this Mac") {
            if b.isPresent {
                HStack(alignment: .top, spacing: UI.gridSpacing) {
                    Card {
                        HStack(spacing: 20) {
                            RingGauge(progress: Double(b.percentage) / 100, label: "\(b.percentage)%", caption: b.isCharging ? "Charging" : "Charge", tint: chargeTint(b.percentage))
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "State", value: b.isCharging ? "Charging" : (b.isPluggedIn ? "Plugged in, not charging" : "On battery"))
                                if let m = b.timeToEmptyMin { InfoRow(label: "Time to empty", value: Formatters.minutes(m)) }
                                if let m = b.timeToFullMin { InfoRow(label: "Time to full", value: Formatters.minutes(m)) }
                                if let v = b.voltageV { InfoRow(label: "Voltage", value: String(format: "%.2f V", v)) }
                                if let a = b.amperageMA { InfoRow(label: "Amperage", value: "\(a) mA") }
                                if let w = b.systemPowerW { InfoRow(label: "Mac is using", value: String(format: "%.1f W", w)) }
                                if let w = b.wallPowerInW { InfoRow(label: "From charger", value: String(format: "%.1f W", w)) }
                                if let w = b.adapterWatts { InfoRow(label: "Charger", value: "\(w) W adapter") }
                            }
                        }
                    }
                    Card(title: "Health", systemImage: "cross.case", accent: .green) {
                        VStack(spacing: 8) {
                            if let h = b.healthPercent {
                                InfoRow(label: "Maximum capacity", value: "\(Int(h))%", valueColor: h < 80 ? .orange : .green)
                                BarMeter(value: h / 100, tint: h < 80 ? .orange : .green)
                            }
                            if let c = b.cycleCount { InfoRow(label: "Cycle count", value: "\(c)") }
                            if let cond = b.health ?? b.condition { InfoRow(label: "Condition", value: cond, valueColor: ["Normal", "Good"].contains(cond) ? .green : .orange) }
                            if let d = b.designCapacity { InfoRow(label: "Design capacity", value: "\(d) mAh") }
                            if let cur = b.currentMaxCapacity { InfoRow(label: "Full-charge capacity", value: "\(cur) mAh") }
                            if let t = sampler.batteryTemp { InfoRow(label: "Temperature", value: String(format: "%.1f °C", t), valueColor: tempTint(t)) }
                        }
                    }
                }
                if !sampler.batteryTempHistory.isEmpty {
                    Card(title: "Battery temperature — last 3 min", systemImage: "thermometer", accent: .orange) {
                        LineSeriesChart(points: sampler.batteryTempHistory, tint: .orange, unit: "°")
                    }
                }
            } else {
                Card { Text("This Mac reports no battery (desktop, or the power source is unavailable).").foregroundStyle(.secondary) }
            }
        }
    }
    private func chargeTint(_ p: Int) -> Color { p < 20 ? .red : (p < 40 ? .orange : .green) }
}
