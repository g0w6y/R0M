import SwiftUI
import Charts
import AppKit

struct BluetoothView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        SectionScaffold(title: "Bluetooth", subtitle: "Battery levels of connected devices") {
            if sampler.btDevices.isEmpty {
                Card {
                    Label("No Bluetooth devices are reporting a battery level right now.", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Text("Only devices that expose a battery level appear here (AirPods, Magic Mouse/Keyboard/Trackpad, some headphones). Connect a device and it shows up within a few seconds.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            } else {
                ForEach(sampler.btDevices) { d in
                    Card {
                        HStack(spacing: 14) {
                            Image(systemName: icon(for: d.name))
                                .font(.system(size: 22))
                                .foregroundStyle(.blue)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(d.name).font(.system(size: 13, weight: .semibold))
                                BarMeter(value: Double(d.battery) / 100.0, tint: battTint(d.battery))
                            }
                            Text("\(d.battery)%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(battTint(d.battery))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
    private func icon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpod") || n.contains("headphone") || n.contains("buds") { return "airpodspro" }
        if n.contains("mouse") { return "magicmouse" }
        if n.contains("keyboard") { return "keyboard" }
        if n.contains("trackpad") { return "trackpad" }
        return "dot.radiowaves.left.and.right"
    }
    private func battTint(_ p: Int) -> Color { p < 20 ? .red : (p < 40 ? .orange : .green) }
}
