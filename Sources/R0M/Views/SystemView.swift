import SwiftUI
import AppKit

struct SystemView: View {
    @EnvironmentObject var sampler: Sampler
    @Local private var showSerial = false
    @Local private var copied = false

    var body: some View {
        let h = sampler.host
        let hw = sampler.hardware
        SectionScaffold(title: "System Info", subtitle: [hw.machineName, h.chip].filter { !$0.isEmpty }.joined(separator: " · ")) {
            HStack(alignment: .top, spacing: UI.gridSpacing) {
                Card(title: "Machine", systemImage: "desktopcomputer", accent: .gray) {
                    VStack(spacing: 8) {
                        InfoRow(label: "Host name", value: h.hostName)
                        if !hw.machineName.isEmpty { InfoRow(label: "Model", value: hw.machineName) }
                        InfoRow(label: "Model identifier", value: h.modelIdentifier)
                        if !hw.modelNumber.isEmpty { InfoRow(label: "Model number", value: hw.modelNumber) }
                        if !hw.serialNumber.isEmpty {
                            HStack {
                                InfoRow(label: "Serial number", value: showSerial ? hw.serialNumber : "••••••••••")
                                Button(showSerial ? "Hide" : "Show") { showSerial.toggle() }.buttonStyle(.link).font(.system(size: 11))
                            }
                        }
                        InfoRow(label: "Chip", value: h.chip)
                        InfoRow(label: "CPU cores", value: h.performanceCores.flatMap { p in h.efficiencyCores.map { "\(h.coreCount) (\(p)P + \($0)E)" } } ?? "\(h.coreCount)")
                        if let g = h.gpuCores { InfoRow(label: "GPU cores", value: "\(g)") }
                        InfoRow(label: "Memory", value: Formatters.bytes(sampler.memory.total))
                    }
                }
                Card(title: "Operating system", systemImage: "gear", accent: .gray) {
                    VStack(spacing: 8) {
                        InfoRow(label: "Version", value: h.osVersion)
                        if !h.osBuild.isEmpty { InfoRow(label: "Build", value: h.osBuild) }
                        if let bt = h.bootTime { InfoRow(label: "Booted", value: Formatters.dateTime.string(from: bt)) }
                        InfoRow(label: "Uptime", value: Formatters.duration(h.uptime))
                        InfoRow(label: "Thermal", value: h.thermalState.label, valueColor: h.thermalState.tint)
                        InfoRow(label: "Low power mode", value: h.lowPowerMode ? "On" : "Off")
                    }
                }
            }

            if !hw.displays.isEmpty {
                Card(title: "Displays", systemImage: "display", accent: .gray) {
                    VStack(spacing: 8) {
                        ForEach(hw.displays) { d in
                            InfoRow(label: d.name, value: [d.resolution, d.kind.capitalized].filter { !$0.isEmpty }.joined(separator: " · "))
                        }
                    }
                }
            }

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Diagnose.textReport(includeSerial: false), forType: .string)
                    copied = true
                } label: { Label(copied ? "Copied" : "Copy system report", systemImage: copied ? "checkmark" : "doc.on.doc") }
                Text("Plain text, serial number excluded — handy for bug reports.").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
            }

            Card(title: "About R0M \(AppInfo.version)", systemImage: "info.circle", accent: .gray) {
                Text("R0M is open source and runs entirely on your Mac: no network connections, no analytics, no helper tools. It reads macOS system counters (Mach, IOKit, sysctl, CoreWLAN) and a few read-only command-line tools. It changes your system only when you ask: clearing the cache folders you select, and setting a power schedule or running a system action (both ask for your password through macOS).")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
