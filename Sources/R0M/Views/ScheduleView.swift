import SwiftUI
import Charts
import AppKit

struct ScheduleView: View {
    @EnvironmentObject var sampler: Sampler
    @Local private var onEnabled = true
    @Local private var onDays: Set<Int> = [0, 1, 2, 3, 4]
    @Local private var onTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @Local private var offEnabled = false
    @Local private var offDays: Set<Int> = [0, 1, 2, 3, 4]
    @Local private var offTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @Local private var offType = "shutdown"
    @Local private var status: String? = nil
    @Local private var statusOK = true

    private let codes = PowerScheduleProbe.weekdayCodes
    private let names = PowerScheduleProbe.weekdayNames

    var body: some View {
        SectionScaffold(title: "Schedule", subtitle: "Automatic power-on, shutdown, and sleep") {
            Card(title: "Current schedule", systemImage: "calendar", accent: .red) {
                Text(sampler.schedule.raw.isEmpty ? "No schedule set." : sampler.schedule.raw)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Card(title: "Power on", systemImage: "power", accent: .green) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Turn the Mac on / wake it", isOn: $onEnabled).font(.system(size: 12, weight: .medium))
                    if onEnabled {
                        dayPicker($onDays)
                        HStack {
                            Text("At").font(.system(size: 12)).foregroundStyle(.secondary)
                            DatePicker("", selection: $onTime, displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                }
            }

            Card(title: "Power off", systemImage: "moon.fill", accent: .indigo) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Shut down or sleep the Mac", isOn: $offEnabled).font(.system(size: 12, weight: .medium))
                    if offEnabled {
                        Picker("Action", selection: $offType) {
                            Text("Shut down").tag("shutdown")
                            Text("Sleep").tag("sleep")
                        }.pickerStyle(.segmented).frame(width: 220)
                        dayPicker($offDays)
                        HStack {
                            Text("At").font(.system(size: 12)).foregroundStyle(.secondary)
                            DatePicker("", selection: $offTime, displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    apply()
                } label: { Label("Apply schedule", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    let r = sampler.cancelSchedule(); status = r.1; statusOK = r.0
                } label: { Label("Cancel all schedules", systemImage: "xmark.circle") }
                Spacer()
            }
            if let status {
                Label(status, systemImage: statusOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundStyle(statusOK ? .green : .orange)
            }

            Text("Applying a schedule uses macOS `pmset` and needs admin rights — you'll get the standard password prompt. Scheduled power-on works best with the Mac plugged in. Only one repeating power-on and one repeating power-off can be active (this replaces any existing repeat).")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private func dayPicker(_ sel: Binding<Set<Int>>) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = sel.wrappedValue.contains(i)
                Text(names[i].prefix(1))
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(on ? Color.accentColor : Color(nsColor: .controlBackgroundColor), in: Circle())
                    .foregroundStyle(on ? .white : .secondary)
                    .overlay(Circle().strokeBorder(.quaternary, lineWidth: on ? 0 : 1))
                    .onTapGesture {
                        if on { sel.wrappedValue.remove(i) } else { sel.wrappedValue.insert(i) }
                    }
            }
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }

    private func apply() {
        let on = onEnabled ? onDays.sorted().map { codes[$0] } : []
        let off = offEnabled ? offDays.sorted().map { codes[$0] } : []
        let r = sampler.applySchedule(onDays: on, onTime: timeString(onTime),
                                      offDays: off, offTime: timeString(offTime), offType: offType)
        status = r.1; statusOK = r.0
    }
}
