import Foundation

struct PowerEvent: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let kind: Kind
    let detail: String
    enum Kind: String { case sleep = "Sleep", wake = "Wake", darkWake = "Dark Wake", reboot = "Boot", shutdown = "Shutdown" }
}

struct PowerHistory {
    var boots: [Date] = []
    var shutdowns: [Date] = []
    var sleepWake: [PowerEvent] = []
    var note: String? = nil
}

enum PowerHistoryProbe {

    static func collect() -> PowerHistory {
        var history = PowerHistory()
        history.boots = parseLast(kind: "reboot")
        history.shutdowns = parseLast(kind: "shutdown")
        history.sleepWake = parsePmsetLog()
        if history.sleepWake.isEmpty && history.boots.isEmpty {
            history.note = "System power logs weren't readable in this context."
        }
        return history
    }

    private static func run(_ launchPath: String, _ args: [String]) -> String {
        Shell.run(launchPath, args, timeout: 30)
    }

    private static func parseLast(kind: String) -> [Date] {
        let out = run("/usr/bin/last", ["-5", kind])
        let weekdays: Set<String> = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let formats = ["EEE MMM d HH:mm", "EEE d MMM HH:mm"]
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var dates: [Date] = []

        for line in out.split(separator: "\n") {
            guard line.hasPrefix(kind) else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

            guard let wdIndex = parts.firstIndex(where: { weekdays.contains($0) }),
                  wdIndex + 3 < parts.count else { continue }
            let tail = parts[wdIndex...(wdIndex + 3)].joined(separator: " ")
            for f in formats {
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = f
                guard let d = fmt.date(from: tail) else { continue }

                var comps = cal.dateComponents([.month, .day, .hour, .minute], from: d)
                comps.year = year
                if let fixed = cal.date(from: comps) {

                    dates.append(fixed > Date() ? cal.date(byAdding: .year, value: -1, to: fixed)! : fixed)
                }
                break
            }
        }
        return dates
    }

    private static func parsePmsetLog() -> [PowerEvent] {
        let out = run("/usr/bin/pmset", ["-g", "log"])
        guard !out.isEmpty else { return [] }
        var events: [PowerEvent] = []
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        for rawLine in out.split(separator: "\n") {
            let line = String(rawLine)

            guard line.count > 30 else { continue }
            let datePart = String(line.prefix(25))
            guard let date = fmt.date(from: datePart) else { continue }
            let rest = line.dropFirst(25).trimmingCharacters(in: .whitespaces)
            let token = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let first = token.first else { continue }
            let type = String(first)
            let detail = token.count > 1 ? String(token[1]).trimmingCharacters(in: .whitespaces) : ""
            let kind: PowerEvent.Kind?
            switch type {
            case "Sleep": kind = .sleep
            case "Wake": kind = .wake
            case "DarkWake": kind = .darkWake
            default: kind = nil
            }
            if let kind {
                events.append(PowerEvent(date: date, kind: kind, detail: String(detail.prefix(90))))
            }
        }
        return Array(events.suffix(40).reversed())
    }
}
