import SwiftUI
import Charts
import AppKit

struct PowerDrawView: View {
    @EnvironmentObject var sampler: Sampler

    private var remainingWh: Double? {
        let b = sampler.battery
        guard let mAh = b.currentMaxCapacity, let v = b.voltageV, b.isPresent else { return nil }
        return Double(b.percentage) / 100.0 * (Double(mAh) / 1000.0) * v
    }
    private var runtimeText: String {
        if sampler.isCharging { return "Charging" }
        guard sampler.wattage > 0.5, let wh = remainingWh else { return "—" }
        let hours = wh / sampler.wattage
        let h = Int(hours), m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    private var drawTint: Color {
        if sampler.isCharging { return .green }
        switch sampler.wattage {
        case ..<6: return .green
        case ..<12: return .yellow
        case ..<20: return .orange
        default: return .red
        }
    }

    var body: some View {
        SectionScaffold(title: "Power Draw", subtitle: "Live battery power flow and what's blocking sleep") {
            HStack(alignment: .top, spacing: UI.gridSpacing) {
                Card {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: sampler.isCharging ? "bolt.fill" : "bolt")
                                    .foregroundStyle(drawTint)
                                Text(sampler.isCharging ? "CHARGING" : "DISCHARGING")
                                    .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(format: "%.1f W", sampler.wattage))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(drawTint)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: sampler.wattage)
                            Text(sampler.isCharging ? "flowing into the battery" : (sampler.battery.systemPowerW != nil ? "total system power draw" : "flowing out of the battery"))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                StatTile(label: sampler.isCharging ? "Status" : "Runtime at this draw",
                         value: runtimeText,
                         sub: remainingWh.map { String(format: "%.1f Wh left", $0) },
                         systemImage: "hourglass", accent: .yellow)
            }

            Card(title: "Power draw — last 3 min", systemImage: "bolt.fill", accent: .yellow) {
                if sampler.wattHistory.count < 2 {
                    Text("Sampling…").font(.system(size: 12)).foregroundStyle(.secondary).frame(height: 120)
                } else {
                    LineSeriesChart(points: sampler.wattHistory, tint: .yellow, unit: "W", height: 150)
                }
            }

            Card(title: "Sleep blockers — what's keeping the Mac awake", systemImage: "moon.zzz", accent: .yellow) {
                VStack(alignment: .leading, spacing: 8) {
                    if sampler.sleepBlockers.isEmpty {
                        Label("Nothing is preventing sleep — the Mac can idle-sleep normally.", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12)).foregroundStyle(.green)
                    } else {
                        ForEach(sampler.sleepBlockers) { b in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: b.process == "caffeinate" ? "cup.and.saucer.fill" : "moon.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(b.process == "caffeinate" ? .orange : .secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 6) {
                                        Text(b.process).font(.system(size: 12, weight: .semibold))
                                        Text("pid \(b.pid)").font(.system(size: 10)).monospacedDigit().foregroundStyle(.tertiary)
                                        Text(b.kind.short).font(.system(size: 9, weight: .semibold))
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(.quaternary, in: Capsule())
                                    }
                                    if !b.detail.isEmpty {
                                        Text(b.detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }
                        Text("A stray `caffeinate` or a media/download app here is the usual reason a Mac drains while idle.")
                            .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 2)
                    }
                }
            }
        }
    }
}
