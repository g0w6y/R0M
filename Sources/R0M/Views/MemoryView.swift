import SwiftUI
import Charts
import AppKit

struct MemoryView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        let m = sampler.memory
        SectionScaffold(title: "Memory", subtitle: "\(Formatters.bytes(m.total)) installed") {
            HStack(alignment: .center, spacing: UI.gridSpacing) {
                Card {
                    HStack(spacing: 20) {
                        RingGauge(progress: m.usedFraction, label: "\(Int(m.usedFraction * 100))%", caption: "Used", tint: levelTint(m.pressureLevel))
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Used", value: Formatters.bytes(m.used))
                            InfoRow(label: "App memory", value: Formatters.bytes(m.appMemory))
                            InfoRow(label: "Wired", value: Formatters.bytes(m.wired))
                            InfoRow(label: "Compressed", value: Formatters.bytes(m.compressed))
                            InfoRow(label: "Cached files", value: Formatters.bytes(m.cached))
                            InfoRow(label: "Free", value: Formatters.bytes(m.free))
                            InfoRow(label: "Memory pressure", value: m.pressureLevel.label, valueColor: levelTint(m.pressureLevel))
                        }
                    }
                }
                Card(title: "Memory used — last 3 min", systemImage: "memorychip", accent: .purple) {
                    PercentAreaChart(points: sampler.memHistory, tint: .purple, height: 150)
                }
            }
            Card(title: "Swap", systemImage: "arrow.left.arrow.right", accent: .purple) {
                VStack(spacing: 8) {
                    InfoRow(label: "Swap used", value: Formatters.bytes(m.swapUsed))
                    InfoRow(label: "Swap total", value: Formatters.bytes(m.swapTotal))
                    if m.swapTotal > 0 {
                        BarMeter(value: Double(m.swapUsed) / Double(m.swapTotal), tint: .purple)
                    }
                }
            }
        }
    }
    private func levelTint(_ l: MemoryPressureLevel) -> Color { l == .normal ? .green : (l == .warning ? .orange : .red) }
}
