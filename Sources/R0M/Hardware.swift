import Foundation

struct DisplayInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let resolution: String
    let kind: String
}

struct HardwareDetails {
    var machineName: String = ""
    var modelNumber: String = ""
    var serialNumber: String = ""
    var memory: String = ""
    var ssdModel: String = ""
    var ssdSize: String = ""
    var ssdSMART: String = ""
    var ssdTrim: String = ""
    var displays: [DisplayInfo] = []
    var isLoaded = false
}

enum HardwareProbe {
    static func collect() -> HardwareDetails {
        var d = HardwareDetails()
        let data = Shell.runData("/usr/sbin/system_profiler",
                                 ["-json", "SPHardwareDataType", "SPNVMeDataType", "SPDisplaysDataType"], timeout: 30)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return d }
        d.isLoaded = true

        if let hw = (root["SPHardwareDataType"] as? [[String: Any]])?.first {
            d.machineName = hw["machine_name"] as? String ?? ""
            d.modelNumber = hw["model_number"] as? String ?? ""
            d.serialNumber = hw["serial_number"] as? String ?? ""
            d.memory = hw["physical_memory"] as? String ?? ""
        }
        if let nvme = (root["SPNVMeDataType"] as? [[String: Any]])?.first,
           let item = (nvme["_items"] as? [[String: Any]])?.first {
            d.ssdModel = item["device_model"] as? String ?? ""
            d.ssdSize = item["size"] as? String ?? ""
            d.ssdSMART = item["smart_status"] as? String ?? ""
            d.ssdTrim = item["spnvme_trim_support"] as? String ?? ""
        }
        if let gpus = root["SPDisplaysDataType"] as? [[String: Any]] {
            for gpu in gpus {
                for disp in (gpu["spdisplays_ndrvs"] as? [[String: Any]]) ?? [] {
                    let type = (disp["spdisplays_display_type"] as? String ?? "")
                        .replacingOccurrences(of: "spdisplays_", with: "")
                        .replacingOccurrences(of: "-", with: " ")
                    d.displays.append(DisplayInfo(
                        name: disp["_name"] as? String ?? "Display",
                        resolution: disp["_spdisplays_resolution"] as? String ?? (disp["_spdisplays_pixels"] as? String ?? ""),
                        kind: type.isEmpty ? ((disp["spdisplays_connection_type"] as? String ?? "").replacingOccurrences(of: "spdisplays_", with: "")) : type))
                }
            }
        }
        return d
    }
}

struct VolumeInfo: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let format: String
    let total: UInt64
    let available: UInt64
    let isInternal: Bool
    let isRemovable: Bool
    var used: UInt64 { total > available ? total - available : 0 }
}

enum VolumeProbe {
    static func all() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
                                      .volumeIsInternalKey, .volumeIsRemovableKey, .volumeLocalizedFormatDescriptionKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let total = v.volumeTotalCapacity, total > 0 else { return nil }
            return VolumeInfo(name: v.volumeName ?? url.lastPathComponent, path: url.path,
                              format: v.volumeLocalizedFormatDescription ?? "",
                              total: UInt64(total),
                              available: UInt64(max(0, v.volumeAvailableCapacityForImportantUsage ?? 0)),
                              isInternal: v.volumeIsInternal ?? true,
                              isRemovable: v.volumeIsRemovable ?? false)
        }
    }
}
