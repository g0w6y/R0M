import Foundation
let fm = FileManager.default
let home = NSHomeDirectory()
var fails = 0
func check(_ name: String, _ ok: Bool) { print(ok ? "PASS" : "FAIL", name); if !ok { fails += 1 } }

let loc = Cleaner.locations.first { $0.id == "dot-cache" }!
try? fm.createDirectory(at: loc.root, withIntermediateDirectories: true)
let tag = "r0m-selftest-\(UUID().uuidString.prefix(8))"
func mk(_ name: String, _ bytes: Int = 4096) -> CleanItem {
    let u = loc.root.appendingPathComponent(name)
    try! fm.createDirectory(at: u, withIntermediateDirectories: true)
    try! Data(count: bytes).write(to: u.appendingPathComponent("blob"))
    return CleanItem(location: loc, name: name, url: u, size: Cleaner.directorySize(u), inUse: false)
}

let a = mk("\(tag)-a")
check("scan finds item", Cleaner.scan().contains { $0.url.path == a.url.path })
check("item passes safety", Cleaner.isSafeToRemove(a))

let r1 = Cleaner.clear([a], mode: .delete)
check("delete removed item", r1.removed == 1 && !fm.fileExists(atPath: a.url.path))

let b = mk("\(tag)-b")
let r2 = Cleaner.clear([b], mode: .trash)
check("trash moved item", r2.removed == 1 && r2.wentToTrash && !fm.fileExists(atPath: b.url.path))
if let t = try? fm.contentsOfDirectory(atPath: home + "/.Trash"), let m = t.first(where: { $0.hasPrefix("\(tag)-b") }) {
    try? fm.removeItem(atPath: home + "/.Trash/" + m); print("  (cleaned test item from Trash)")
}

let victim = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(tag)-victim")
try! fm.createDirectory(at: victim, withIntermediateDirectories: true)
let outside = CleanItem(location: loc, name: "victim", url: victim, size: 1, inUse: false)
check("rejects item outside root", !Cleaner.isSafeToRemove(outside))
let dotdot = CleanItem(location: loc, name: "..", url: loc.root.appendingPathComponent(".."), size: 1, inUse: false)
check("rejects '..'", !Cleaner.isSafeToRemove(dotdot))
let nested = CleanItem(location: loc, name: "x", url: loc.root.appendingPathComponent("a/b"), size: 1, inUse: false)
check("rejects grandchild", !Cleaner.isSafeToRemove(nested))

let link = loc.root.appendingPathComponent("\(tag)-link")
try! fm.createSymbolicLink(at: link, withDestinationURL: victim)
try! Data(count: 10).write(to: victim.appendingPathComponent("payload"))
let viaLink = CleanItem(location: loc, name: "payload", url: link.appendingPathComponent("payload"), size: 1, inUse: false)
check("rejects path through symlinked dir", !Cleaner.isSafeToRemove(viaLink))
_ = Cleaner.clear([viaLink], mode: .delete)
check("victim file survived", fm.fileExists(atPath: victim.appendingPathComponent("payload").path))

let linkItem = CleanItem(location: loc, name: link.lastPathComponent, url: link, size: 1, inUse: false)
let r3 = Cleaner.clear([linkItem], mode: .delete)
check("symlink child removed, target kept", r3.removed == 1 && !fm.fileExists(atPath: link.path) && fm.fileExists(atPath: victim.path))

let fake = CleanLocation(id: "user-caches", title: "x", detail: "", root: URL(fileURLWithPath: "/"), scope: .user, risk: .safe)
let forged = CleanItem(location: fake, name: "etc", url: URL(fileURLWithPath: "/etc"), size: 1, inUse: false)
check("rejects forged location", !Cleaner.isSafeToRemove(forged))

check("quote escapes '", Admin.quote("a'b") == "'a'\\''b'")
try? fm.removeItem(at: victim)
print(fails == 0 ? "ALL PASSED" : "\(fails) FAILED")
exit(fails == 0 ? 0 : 1)
