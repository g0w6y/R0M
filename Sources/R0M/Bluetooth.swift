import Foundation

struct BTDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let battery: Int
}

enum BluetoothProbe {

    static func devices() -> [BTDevice] {

        let data = Shell.runData("/usr/sbin/ioreg", ["-a", "-r", "-k", "BatteryPercent"])
        guard !data.isEmpty else { return [] }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return [] }

        let nodes: [[String: Any]]
        if let arr = plist as? [[String: Any]] { nodes = arr }
        else if let one = plist as? [String: Any] { nodes = [one] }
        else { return [] }

        var out: [BTDevice] = []
        var seen = Set<String>()
        for node in nodes {
            guard let pct = node["BatteryPercent"] as? Int, pct >= 0, pct <= 100 else { continue }
            let name = (node["Product"] as? String)
                ?? (node["DeviceName"] as? String)
                ?? (node["BD_ADDR"] as? String)
                ?? "Bluetooth device"
            let key = "\(name)-\(pct)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(BTDevice(name: name, battery: pct))
        }
        return out.sorted { $0.battery < $1.battery }
    }
}
