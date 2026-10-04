import SwiftUI
import Charts
import AppKit

struct GPUView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        SectionScaffold(title: "GPU", subtitle: gpuSubtitle) {
            if sampler.gpuAvailable {
                HStack(alignment: .center, spacing: UI.gridSpacing) {
                    Card {
                        HStack(spacing: 20) {
                            RingGauge(progress: sampler.gpuUsage, label: "\(Int(sampler.gpuUsage * 100))%", caption: "GPU load", tint: .mint)
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "Chip", value: sampler.host.chip)
                                InfoRow(label: "GPU cores", value: sampler.host.gpuCores.map(String.init) ?? "—")
                                InfoRow(label: "Utilization", value: "\(Int(sampler.gpuUsage * 100))%")
                            }
                        }
                    }
                    Card(title: "GPU load — last 3 min", systemImage: "cpu.fill", accent: .mint) {
                        PercentAreaChart(points: sampler.gpuHistory, tint: .mint, height: 150)
                    }
                }
                Text("GPU utilization is read from the IORegistry accelerator (Device Utilization %). It reflects overall graphics/compute activity, not per-app usage.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            } else {
                Card { Text("GPU utilization counter isn't exposed on this system.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
        }
    }
    private var gpuSubtitle: String { sampler.gpuAvailable ? "Integrated Apple-Silicon GPU" : "Unavailable" }
}
