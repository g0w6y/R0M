import Foundation

enum Admin {

    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func run(_ command: String, success: String = "Done.") -> (ok: Bool, message: String) {

        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else { return (false, "Could not build request.") }
        var err: NSDictionary?
        _ = script.executeAndReturnError(&err)
        if let err {
            if let n = err[NSAppleScript.errorNumber] as? Int, n == -128 {
                return (false, "Cancelled — no change made.")
            }
            return (false, (err[NSAppleScript.errorMessage] as? String) ?? "Authorization failed.")
        }
        return (true, success)
    }
}
