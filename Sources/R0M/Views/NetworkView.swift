import SwiftUI
import Charts
import AppKit

struct NetworkView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        SectionScaffold(title: "Network", subtitle: "Live throughput on physical interfaces (VPN tunnels excluded, so nothing is double-counted)") {
            HStack(spacing: UI.gridSpacing) {
                StatTile(label: "Download", value: Formatters.rate(sampler.netInRate), systemImage: "arrow.down.circle", accent: .blue)
                StatTile(label: "Upload", value: Formatters.rate(sampler.netOutRate), systemImage: "arrow.up.circle", accent: .green)
                StatTile(label: "Interface", value: sampler.primaryInterface, sub: sampler.localIP, systemImage: "wifi", accent: .teal)
                StatTile(label: "This session", value: "↓ " + Formatters.fileBytes(sampler.netSessionIn), sub: "↑ " + Formatters.fileBytes(sampler.netSessionOut) + " since launch", systemImage: "chart.bar", accent: .teal)
            }
            Card(title: "Throughput — last 3 min", systemImage: "network", accent: .teal) {
                VStack(alignment: .leading, spacing: 10) {
                    NetworkChart(inPoints: sampler.netInHistory, outPoints: sampler.netOutHistory)
                    HStack(spacing: 16) {
                        LegendDot(color: .blue, text: "Download")
                        LegendDot(color: .green, text: "Upload")
                    }
                }
            }

            if let w = sampler.wifi, w.powered {
                Card(title: "Wi-Fi", systemImage: "wifi", accent: .teal) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let ssid = w.ssid {
                                InfoRow(label: "Network", value: ssid)
                            } else if w.ssidRestricted {
                                InfoRow(label: "Network", value: "Hidden (grant Location)", valueColor: .secondary)
                            }
                            if let sec = w.security { InfoRow(label: "Security", value: sec) }
                            InfoRow(label: "Interface", value: w.interfaceName)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            if let r = w.rssi {
                                InfoRow(label: "Signal (RSSI)", value: "\(r) dBm", valueColor: signalColor(w.signalQuality))
                                BarMeter(value: w.signalQuality ?? 0, tint: signalColor(w.signalQuality))
                            }
                            if let tx = w.txRate { InfoRow(label: "TX rate", value: String(format: "%.0f Mbps", tx)) }
                            if let ch = w.channel { InfoRow(label: "Channel", value: "\(ch)" + (w.band.map { " · \($0)" } ?? "")) }
                            if let n = w.noise { InfoRow(label: "Noise", value: "\(n) dBm") }
                        }
                    }
                }
            } else if let w = sampler.wifi, !w.powered {
                Card { Text("Wi-Fi is powered off.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
        }
    }
    private func signalColor(_ q: Double?) -> Color {
        guard let q else { return .secondary }
        return q > 0.6 ? .green : (q > 0.3 ? .yellow : .orange)
    }
}
