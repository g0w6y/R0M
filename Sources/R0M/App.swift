import SwiftUI
import Charts
import AppKit
import ServiceManagement

@main
struct R0MApp: App {
    @StateObject private var sampler = Sampler()

    init() {

        if CommandLine.arguments.contains("--diagnose") {
            Diagnose.printReport()
            exit(0)
        }
    }

    var body: some Scene {

        Window("R0M", id: "main") {
            ContentView()
                .environmentObject(sampler)
                .frame(minWidth: 940, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent().environmentObject(sampler)
        } label: {
            MenuBarLabel(sampler: sampler)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(sampler)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var sampler: Sampler
    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: Glyph.menuBar)
            Text(text).monospacedDigit()
        }
        .onAppear { sampler.start() }
    }
    private var text: String {
        var parts = ["\(Int(sampler.cpuUsage * 100))%"]
        if sampler.showTempInMenuBar, let t = sampler.thermal.cpuAverage { parts.append("\(Int(t.rounded()))°") }
        if sampler.battery.isPresent {
            parts.append("\(sampler.battery.percentage)%")
            if sampler.wattage > 0 { parts.append(String(format: "%.0fW", sampler.wattage)) }
        }
        return parts.joined(separator: " · ")
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var sampler: Sampler
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(nsImage: Glyph.appIcon).resizable().frame(width: 20, height: 20)
                Text("R0M").font(.system(size: 14, weight: .heavy, design: .rounded))
                Spacer()
                Text(sampler.host.chip).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Divider()
            menuRow("cpu", "CPU", "\(Int(sampler.cpuUsage * 100))%", .blue)
            if let t = sampler.thermal.cpuAverage { menuRow("thermometer.medium", "CPU temp", String(format: "%.0f °C", t), tempTint(t)) }
            if sampler.gpuAvailable { menuRow("cpu.fill", "GPU", "\(Int(sampler.gpuUsage * 100))%", .mint) }
            menuRow("memorychip", "Memory", "\(Int(sampler.memory.usedFraction * 100))% · \(sampler.memory.pressureLevel.label)", .purple)
            if sampler.battery.isPresent {
                menuRow("battery.100percent", "Battery", "\(sampler.battery.percentage)%" + (sampler.isCharging ? " ⚡" : ""), .green)
                menuRow("bolt.fill", sampler.isCharging ? "Charging at" : "Power draw", String(format: "%.1f W", sampler.wattage), .yellow)
            }
            menuRow("arrow.down.arrow.up", "Network", "↓\(Formatters.rate(sampler.netInRate))  ↑\(Formatters.rate(sampler.netOutRate))", .teal)
            menuRow("gauge.with.needle", "Thermal state", sampler.host.thermalState.label, sampler.host.thermalState.tint)
            Divider()
            HStack {
                Button("Open R0M") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.system(size: 12))
        }
        .padding(14)
        .frame(width: 310)
    }
    private func menuRow(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 18)
            Text(label).font(.system(size: 12))
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var sampler: Sampler
    @Local private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Local private var loginError: String?

    var body: some View {
        Form {
            Picker("Refresh every", selection: $sampler.sampleInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
            }
            Toggle("Show CPU temperature in the menu bar", isOn: $sampler.showTempInMenuBar)
            Toggle("Launch R0M at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.orange) }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 220)
    }
}

enum Page: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "Memory"
    case thermal = "Thermal"
    case battery = "Battery"
    case powerDraw = "Power Draw"
    case storage = "Storage"
    case network = "Network"
    case bluetooth = "Bluetooth"
    case cleaner = "Cleaner"
    case power = "Power & Uptime"
    case schedule = "Schedule"
    case system = "System Info"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .cpu: return "cpu"
        case .gpu: return "cpu.fill"
        case .memory: return "memorychip"
        case .thermal: return "thermometer.medium"
        case .battery: return "battery.100percent"
        case .powerDraw: return "bolt.fill"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .cleaner: return "sparkles"
        case .power: return "powersleep"
        case .schedule: return "calendar.badge.clock"
        case .system: return "desktopcomputer"
        }
    }

    static let groups: [(title: String, pages: [Page])] = [
        ("Monitor", [.overview, .cpu, .gpu, .memory, .thermal]),
        ("Power", [.battery, .powerDraw, .power, .schedule]),
        ("Devices", [.storage, .network, .bluetooth]),
        ("Tools", [.cleaner, .system]),
    ]
}

struct ContentView: View {
    @EnvironmentObject var sampler: Sampler
    @Local private var selection: Page = Page(rawValue: UserDefaults.standard.string(forKey: "lastPage") ?? "") ?? .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Page.groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.pages) { page in
                            NavigationLink(value: page) {
                                Label(page.rawValue, systemImage: page.icon)
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
            .safeAreaInset(edge: .top) { sidebarHeader }
        } detail: {
            detailView
                .navigationTitle(selection.rawValue)
        }
        .onChange(of: selection) { _, page in UserDefaults.standard.set(page.rawValue, forKey: "lastPage") }
        .onAppear { sampler.start(); sampler.detailVisible = true }
        .onDisappear { sampler.detailVisible = false }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: Glyph.appIcon)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text("R0M").font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(sampler.host.hostName).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder private var detailView: some View {
        switch selection {
        case .overview: OverviewView()
        case .cpu: CPUView()
        case .gpu: GPUView()
        case .memory: MemoryView()
        case .thermal: ThermalView()
        case .battery: BatteryView()
        case .powerDraw: PowerDrawView()
        case .storage: StorageView()
        case .network: NetworkView()
        case .bluetooth: BluetoothView()
        case .cleaner: CleanerView()
        case .power: PowerView()
        case .schedule: ScheduleView()
        case .system: SystemView()
        }
    }
}

func tempTint(_ c: Double) -> Color {
    switch c {
    case ..<55: return .green
    case ..<75: return .yellow
    case ..<90: return .orange
    default: return .red
    }
}
