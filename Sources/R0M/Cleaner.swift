import Foundation
import AppKit

enum CleanScope: String { case user = "User", system = "System (admin)" }
enum CleanRisk { case safe, review }

struct CleanLocation: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let root: URL
    let scope: CleanScope
    let risk: CleanRisk
}

struct CleanItem: Identifiable, Hashable {
    var id: String { url.path }
    let location: CleanLocation
    let name: String
    let url: URL
    let size: UInt64
    let inUse: Bool
}

enum CleanMode: String, CaseIterable, Identifiable {
    case trash = "Move to Trash"
    case delete = "Delete permanently"
    var id: String { rawValue }
}

struct CleanResult {
    var removed = 0
    var reclaimed: UInt64 = 0
    var skipped: [String] = []
    var wentToTrash = false
}

enum Cleaner {
    private static var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }

    static var locations: [CleanLocation] {
        let lib = home.appendingPathComponent("Library")
        return [
            CleanLocation(id: "user-caches", title: "App caches", detail: "~/Library/Caches — apps rebuild these on demand",
                          root: lib.appendingPathComponent("Caches"), scope: .user, risk: .safe),
            CleanLocation(id: "user-logs", title: "App logs & crash reports", detail: "~/Library/Logs",
                          root: lib.appendingPathComponent("Logs"), scope: .user, risk: .safe),
            CleanLocation(id: "xcode-derived", title: "Xcode build data", detail: "DerivedData — Xcode rebuilds it",
                          root: lib.appendingPathComponent("Developer/Xcode/DerivedData"), scope: .user, risk: .safe),
            CleanLocation(id: "sim-caches", title: "Simulator caches", detail: "~/Library/Developer/CoreSimulator/Caches",
                          root: lib.appendingPathComponent("Developer/CoreSimulator/Caches"), scope: .user, risk: .safe),
            CleanLocation(id: "xcode-devsupport", title: "Xcode device support", detail: "Re-downloaded the next time you plug that device in",
                          root: lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"), scope: .user, risk: .review),
            CleanLocation(id: "npm", title: "npm cache", detail: "~/.npm/_cacache",
                          root: home.appendingPathComponent(".npm/_cacache"), scope: .user, risk: .safe),
            CleanLocation(id: "dot-cache", title: "Developer tool caches", detail: "~/.cache (pip, huggingface, …)",
                          root: home.appendingPathComponent(".cache"), scope: .user, risk: .review),
            CleanLocation(id: "gradle", title: "Gradle caches", detail: "~/.gradle/caches — slow to re-download",
                          root: home.appendingPathComponent(".gradle/caches"), scope: .user, risk: .review),
            CleanLocation(id: "sys-caches", title: "System caches", detail: "/Library/Caches — needs admin; protected items are skipped",
                          root: URL(fileURLWithPath: "/Library/Caches"), scope: .system, risk: .review),
            CleanLocation(id: "sys-logs", title: "System logs", detail: "/Library/Logs — needs admin",
                          root: URL(fileURLWithPath: "/Library/Logs"), scope: .system, risk: .review),
        ]
    }

    static var trashURL: URL { home.appendingPathComponent(".Trash") }

    static func scan() -> [CleanItem] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        let fm = FileManager.default

        var pending: [(CleanLocation, URL)] = []
        for loc in locations {
            guard let kids = try? fm.contentsOfDirectory(at: loc.root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            pending += kids.map { (loc, $0) }
        }

        var items = [CleanItem?](repeating: nil, count: pending.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: pending.count) { i in
            let (loc, url) = pending[i]
            let size = directorySize(url)
            let name = url.lastPathComponent
            let item = CleanItem(location: loc, name: name, url: url, size: size,
                                 inUse: running.contains(name.lowercased()))
            lock.lock(); items[i] = item; lock.unlock()
        }
        return items.compactMap { $0 }.filter { $0.size > 0 }.sorted { $0.size > $1.size }
    }

    static func directorySize(_ url: URL) -> UInt64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: Set(keys))
            return UInt64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: UInt64 = 0
        for case let f as URL in en {
            let v = try? f.resourceValues(forKeys: Set(keys))
            total &+= UInt64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        return total
    }

    static func trashSize() -> UInt64? {
        guard (try? FileManager.default.contentsOfDirectory(atPath: trashURL.path)) != nil else { return nil }
        return directorySize(trashURL)
    }

    static func isSafeToRemove(_ item: CleanItem) -> Bool {
        let name = item.url.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
        guard locations.contains(where: { $0.id == item.location.id && $0.root == item.location.root }) else { return false }
        let root = item.location.root.resolvingSymlinksInPath().standardizedFileURL.path
        let parent = item.url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        guard parent == root else { return false }
        switch item.location.scope {
        case .user:
            let h = home.resolvingSymlinksInPath().standardizedFileURL.path
            return root.hasPrefix(h + "/")
        case .system:
            return root == "/Library/Caches" || root == "/private/Library/Caches"
                || root == "/Library/Logs" || root == "/private/Library/Logs"
        }
    }

    static func clear(_ items: [CleanItem], mode: CleanMode) -> CleanResult {
        var result = CleanResult()
        let fm = FileManager.default
        let safe = items.filter { item in
            if isSafeToRemove(item) { return true }
            result.skipped.append("\(item.name): failed safety check")
            return false
        }

        for item in safe where item.location.scope == .user {
            do {
                if mode == .trash {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    result.wentToTrash = true
                } else {
                    try fm.removeItem(at: item.url)
                }
                result.removed += 1
                result.reclaimed &+= item.size
            } catch {
                result.skipped.append("\(item.name): \(error.localizedDescription)")
            }
        }

        let sys = safe.filter { $0.location.scope == .system }
        if !sys.isEmpty {
            let paths = sys.map { Admin.quote($0.url.path) }.joined(separator: " ")

            let cmd = "for p in \(paths); do /bin/rm -rf -- \"$p\" 2>/dev/null; done; exit 0"
            let r = Admin.run(cmd)
            if !r.ok {
                result.skipped.append("System items: \(r.message)")
            } else {
                for item in sys {
                    if fm.fileExists(atPath: item.url.path) {
                        result.skipped.append("\(item.name): protected by macOS")
                    } else {
                        result.removed += 1
                        result.reclaimed &+= item.size
                    }
                }
            }
        }
        return result
    }

    static func emptyTrash() -> (Bool, String) {
        var err: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\" to empty the trash")?.executeAndReturnError(&err)
        if let err {
            let msg = (err[NSAppleScript.errorMessage] as? String) ?? "Finder refused."
            return (false, "Couldn't empty the Trash: \(msg)")
        }
        return (true, "Trash emptied.")
    }

    static func flushDNS() -> (Bool, String) {
        let r = Admin.run("/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder; exit 0", success: "DNS cache flushed.")
        return (r.ok, r.message)
    }

    static func purgeMemory() -> (Bool, String) {
        let r = Admin.run("/usr/sbin/purge", success: "Inactive memory purged.")
        return (r.ok, r.message)
    }
}
