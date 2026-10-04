import Foundation
import CoreWLAN

struct WiFiSnapshot {
    var powered = false
    var interfaceName: String = "—"
    var ssid: String? = nil
    var ssidRestricted = false
    var rssi: Int? = nil
    var noise: Int? = nil
    var txRate: Double? = nil
    var channel: Int? = nil
    var band: String? = nil
    var security: String? = nil

    var signalQuality: Double? {
        guard let r = rssi else { return nil }
        return max(0, min(1, Double(r + 100) / 50.0))
    }
}

enum WiFiProbe {
    static func snapshot() -> WiFiSnapshot? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }
        var s = WiFiSnapshot()
        s.interfaceName = iface.interfaceName ?? "Wi-Fi"
        s.powered = iface.powerOn()
        guard s.powered else { return s }

        let rssi = iface.rssiValue()
        if rssi != 0 { s.rssi = rssi }
        let noise = iface.noiseMeasurement()
        if noise != 0 { s.noise = noise }
        let tx = iface.transmitRate()
        if tx > 0 { s.txRate = tx }
        if let ch = iface.wlanChannel() {
            s.channel = ch.channelNumber
            switch ch.channelBand {
            case .band2GHz: s.band = "2.4 GHz"
            case .band5GHz: s.band = "5 GHz"
            case .band6GHz: s.band = "6 GHz"
            default: s.band = nil
            }
        }
        if let ssid = iface.ssid(), !ssid.isEmpty {
            s.ssid = ssid
        } else if s.rssi != nil {

            s.ssidRestricted = true
        }
        switch iface.security() {
        case .none: s.security = "Open"
        case .WEP: s.security = "WEP"
        case .wpaPersonal, .wpaPersonalMixed: s.security = "WPA"
        case .wpa2Personal: s.security = "WPA2"
        case .wpa3Personal, .wpa3Transition: s.security = "WPA3"
        case .enterprise, .wpaEnterprise, .wpa2Enterprise, .wpa3Enterprise: s.security = "Enterprise"
        default: s.security = nil
        }
        return s
    }
}
