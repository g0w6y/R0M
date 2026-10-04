import Foundation

struct PowerScheduleState {
    var raw: String = ""
    var hasRepeat: Bool = false
}

enum PowerScheduleProbe {

    static let weekdayCodes = ["M", "T", "W", "R", "F", "S", "U"]
    static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func current() -> PowerScheduleState {
        let out = Shell.run("/usr/bin/pmset", ["-g", "sched"])
        var s = PowerScheduleState()
        s.raw = out.trimmingCharacters(in: .whitespacesAndNewlines)
        s.hasRepeat = out.lowercased().contains("repeating")
        return s
    }

    static func apply(onDays: [String], onTime: String,
                      offDays: [String], offTime: String, offType: String) -> (Bool, String) {

        let valid = Set(weekdayCodes)
        guard onDays.allSatisfy(valid.contains), offDays.allSatisfy(valid.contains),
              ["shutdown", "sleep"].contains(offType),
              isClock(onTime), isClock(offTime) else {
            return (false, "Invalid schedule values.")
        }
        var parts: [String] = []
        if !onDays.isEmpty { parts += ["poweron", onDays.joined(), onTime] }
        if !offDays.isEmpty { parts += [offType, offDays.joined(), offTime] }
        guard !parts.isEmpty else { return (false, "Pick at least one day for power-on or power-off.") }
        return Admin.run("/usr/bin/pmset repeat " + parts.joined(separator: " "), success: "Schedule updated.")
    }

    static func cancel() -> (Bool, String) {
        Admin.run("/usr/bin/pmset repeat cancel", success: "Schedule cancelled.")
    }

    private static func isClock(_ s: String) -> Bool {
        s.range(of: #"^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$"#, options: .regularExpression) != nil
    }
}
