import SwiftUI
import Charts
import AppKit

struct PowerView: View {
    @EnvironmentObject var sampler: Sampler
    var body: some View {
        let h = sampler.powerHistory
        SectionScaffold(title: "Power & Uptime", subtitle: "Boot, sleep, wake and shutdown history") {
            HStack(spacing: UI.gridSpacing) {
                StatTile(label: "Uptime", value: Formatters.duration(sampler.host.uptime), systemImage: "clock", accent: .pink)
                if let bt = sampler.host.bootTime {
                    StatTile(label: "Booted", value: Formatters.dateTime.string(from: bt), systemImage: "power", accent: .pink)
                }
                if let lastShut = h.shutdowns.first {
                    StatTile(label: "Last shutdown", value: Formatters.dateTime.string(from: lastShut), systemImage: "poweroff", accent: .red)
                }
                if let lastWake = h.sleepWake.first(where: { $0.kind == .wake })?.date {
                    StatTile(label: "Last wake", value: Formatters.dateTime.string(from: lastWake), systemImage: "sun.max", accent: .yellow)
                }
            }

            HStack(alignment: .top, spacing: UI.gridSpacing) {
                Card(title: "Recent boots", systemImage: "power", accent: .pink) {
                    DateList(dates: h.boots, empty: "No boot records.")
                }
                Card(title: "Recent shutdowns", systemImage: "poweroff", accent: .red) {
                    DateList(dates: h.shutdowns, empty: "No shutdown records.")
                }
            }

            Card(title: "Sleep / Wake log", systemImage: "powersleep", accent: .pink) {
                VStack(alignment: .leading, spacing: 6) {
                    if h.sleepWake.isEmpty {
                        Text(h.note ?? "No sleep/wake events available.").font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                        ForEach(h.sleepWake) { e in
                            HStack(alignment: .top) {
                                Text(e.kind.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(kindColor(e.kind))
                                    .frame(width: 78, alignment: .leading)
                                Text(Formatters.dateTime.string(from: e.date)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                                Text(e.detail).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
    private func kindColor(_ k: PowerEvent.Kind) -> Color {
        switch k {
        case .sleep: return .indigo
        case .wake: return .yellow
        case .darkWake: return .orange
        case .reboot: return .green
        case .shutdown: return .red
        }
    }
}

struct DateList: View {
    let dates: [Date]
    let empty: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if dates.isEmpty {
                Text(empty).font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, d in
                    HStack {
                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary)
                        Text(Formatters.dateTime.string(from: d)).font(.system(size: 12)).monospacedDigit()
                        Spacer()
                    }
                }
            }
        }
    }
}
