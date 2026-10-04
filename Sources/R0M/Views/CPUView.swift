import SwiftUI
import Charts
import AppKit

struct CPUView: View {
    @EnvironmentObject var sampler: Sampler
    private let coreCols = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        SectionScaffold(title: "CPU", subtitle: sampler.host.chip) {
            HStack(alignment: .center, spacing: UI.gridSpacing) {
                Card {
                    HStack(spacing: 20) {
                        RingGauge(progress: sampler.cpuUsage, label: "\(Int(sampler.cpuUsage * 100))%", caption: "Total load", tint: .blue)
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Cores (logical)", value: "\(sampler.host.coreCount)")
                            if let p = sampler.host.performanceCores { InfoRow(label: "Performance cores", value: "\(p)") }
                            if let e = sampler.host.efficiencyCores { InfoRow(label: "Efficiency cores", value: "\(e)") }
                            InfoRow(label: "Active cores", value: "\(sampler.perCoreUsage.filter { $0 > 0.05 }.count)")
                        }
                    }
                }
                Card(title: "Load — last 3 min", systemImage: "waveform.path", accent: .blue) {
                    PercentAreaChart(points: sampler.cpuHistory, tint: .blue, height: 150)
                }
            }

            Card(title: "Per-core utilization", systemImage: "cpu", accent: .blue) {
                LazyVGrid(columns: coreCols, spacing: 12) {
                    ForEach(Array(sampler.perCoreUsage.enumerated()), id: \.offset) { idx, usage in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Core \(idx)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(usage * 100))%").font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            }
                            BarMeter(value: usage, tint: coreTint(usage))
                        }
                    }
                }
            }
        }
    }
    private func coreTint(_ v: Double) -> Color { v > 0.8 ? .red : (v > 0.5 ? .orange : .blue) }
}
