import Foundation

struct SleepBlocker: Identifiable, Hashable {
    let id = UUID()
    let pid: Int
    let process: String
    let kind: Kind
    let detail: String
    enum Kind: String {
        case system = "System sleep"
        case display = "Display sleep"
        case idle = "Idle sleep"
        var short: String { self == .display ? "Display" : "System" }
    }
}

enum SleepBlockerProbe {

    static func collect() -> [SleepBlocker] {
        let out = Shell.run("/usr/bin/pmset", ["-g", "assertions"])
        guard !out.isEmpty else { return [] }

        var blockers: [SleepBlocker] = []
        var seen = Set<String>()
        for rawLine in out.split(separator: "\n") {
            let line = String(rawLine)

            guard line.contains("pid "), line.contains("Prevent") else { continue }
            let kind: SleepBlocker.Kind
            if line.contains("PreventUserIdleDisplaySleep") { kind = .display }
            else if line.contains("PreventSystemSleep") { kind = .system }
            else if line.contains("PreventUserIdleSystemSleep") { kind = .idle }
            else { continue }

            guard let pidRange = line.range(of: #"pid (\d+)\(([^)]*)\)"#, options: .regularExpression) else { continue }
            let match = String(line[pidRange])
            let inner = match.dropFirst(4)
            let parts = inner.split(separator: "(", maxSplits: 1)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            let name = String(parts[1].dropLast())

            var detail = ""
            if let r = line.range(of: #"named: "([^"]*)""#, options: .regularExpression) {
                detail = String(line[r]).replacingOccurrences(of: "named: \"", with: "").replacingOccurrences(of: "\"", with: "")
            }

            if name == "powerd" && detail.contains("display is on") { continue }

            let dedupe = "\(pid)-\(kind.rawValue)"
            guard !seen.contains(dedupe) else { continue }
            seen.insert(dedupe)
            blockers.append(SleepBlocker(pid: pid, process: name, kind: kind, detail: String(detail.prefix(80))))
        }

        return blockers.sorted { ($0.process == "caffeinate" ? 0 : 1, $0.pid) < ($1.process == "caffeinate" ? 0 : 1, $1.pid) }
    }
}
