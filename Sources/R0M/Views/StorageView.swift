import SwiftUI
import Charts
import AppKit

struct StorageView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        let d = sampler.disk
        let usedFrac = d.total > 0 ? Double(d.used) / Double(d.total) : 0
        SectionScaffold(title: "Storage", subtitle: "Startup volume") {
            HStack(alignment: .center, spacing: UI.gridSpacing) {
                Card {
                    HStack(spacing: 20) {
                        RingGauge(progress: usedFrac, label: "\(Int(usedFrac * 100))%", caption: "Used", tint: usedFrac > 0.9 ? .red : .indigo)
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Total", value: Formatters.fileBytes(d.total))
                            InfoRow(label: "Used", value: Formatters.fileBytes(d.used))
                            InfoRow(label: "Available", value: Formatters.fileBytes(d.available), valueColor: usedFrac > 0.9 ? .orange : .primary)
                        }
                    }
                }
                VStack(spacing: UI.gridSpacing) {
                    StatTile(label: "Disk read", value: Formatters.rate(sampler.diskReadRate), systemImage: "arrow.down.doc", accent: .indigo)
                    StatTile(label: "Disk write", value: Formatters.rate(sampler.diskWriteRate), systemImage: "arrow.up.doc", accent: .indigo)
                }
                .frame(maxWidth: 220)
            }

            Card(title: "Disk I/O — last 3 min", systemImage: "internaldrive", accent: .indigo) {
                VStack(alignment: .leading, spacing: 10) {
                    NetworkChart(inPoints: sampler.diskReadHistory, outPoints: sampler.diskWriteHistory)
                    HStack(spacing: 16) {
                        LegendDot(color: .blue, text: "Read")
                        LegendDot(color: .green, text: "Write")
                    }
                }
            }

            if !sampler.hardware.ssdModel.isEmpty {
                Card(title: "Internal SSD", systemImage: "internaldrive", accent: .indigo) {
                    VStack(spacing: 8) {
                        InfoRow(label: "Model", value: sampler.hardware.ssdModel)
                        InfoRow(label: "Capacity", value: sampler.hardware.ssdSize)
                        if !sampler.hardware.ssdSMART.isEmpty {
                            InfoRow(label: "SMART status", value: sampler.hardware.ssdSMART,
                                    valueColor: sampler.hardware.ssdSMART == "Verified" ? .green : .orange)
                        }
                        if !sampler.hardware.ssdTrim.isEmpty { InfoRow(label: "TRIM", value: sampler.hardware.ssdTrim) }
                        if let t = sampler.thermal.ssd { InfoRow(label: "Temperature", value: String(format: "%.0f °C", t), valueColor: tempTint(t)) }
                    }
                }
            }

            if sampler.volumes.count > 0 {
                Card(title: "Mounted volumes", systemImage: "externaldrive", accent: .indigo) {
                    VStack(spacing: 12) {
                        ForEach(sampler.volumes) { v in
                            VStack(spacing: 5) {
                                HStack {
                                    Image(systemName: v.isInternal ? "internaldrive" : "externaldrive.fill")
                                        .foregroundStyle(.indigo).frame(width: 18)
                                    Text(v.name).font(.system(size: 12, weight: .semibold))
                                    if !v.format.isEmpty { Text(v.format).font(.system(size: 10)).foregroundStyle(.tertiary) }
                                    Spacer()
                                    Text("\(Formatters.fileBytes(v.available)) free of \(Formatters.fileBytes(v.total))")
                                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                                }
                                BarMeter(value: Double(v.used) / Double(max(1, v.total)),
                                         tint: Double(v.used) / Double(max(1, v.total)) > 0.9 ? .red : .indigo, height: 6)
                            }
                        }
                    }
                }
            }

            Text("“Available” reflects space macOS can reclaim (including purgeable). The Cleaner tab can free additional room.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}
