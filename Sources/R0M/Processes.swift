import Foundation

struct ProcInfo: Identifiable, Hashable {
    let id = UUID()
    let pid: Int
    let cpu: Double
    let mem: Double
    let command: String
}

enum ProcessProbe {

    static func top(by sort: String = "cpu", limit: Int = 8) -> [ProcInfo] {

        let out = Shell.run("/bin/ps", ["-Aro", "pid=,%cpu=,%mem=,comm="])
        guard !out.isEmpty else { return [] }

        var procs: [ProcInfo] = []
        for line in out.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else { continue }
            let full = String(parts[3])
            let name = (full as NSString).lastPathComponent
            procs.append(ProcInfo(pid: pid, cpu: cpu, mem: mem, command: name.isEmpty ? full : name))
        }
        if sort == "mem" { procs.sort { $0.mem > $1.mem } }
        return Array(procs.prefix(limit))
    }
}
