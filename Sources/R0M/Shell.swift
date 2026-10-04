import Foundation

enum Shell {

    static func run(_ path: String, _ args: [String] = [], timeout: TimeInterval = 15) -> String {
        String(data: runData(path, args, timeout: timeout), encoding: .utf8) ?? ""
    }

    static func runData(_ path: String, _ args: [String] = [], timeout: TimeInterval = 15) -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice
        do { try proc.run() } catch { return Data() }

        var collected = Data()
        let reader = DispatchGroup()
        reader.enter()
        DispatchQueue.global(qos: .utility).async {
            collected = out.fileHandleForReading.readDataToEndOfFile()
            reader.leave()
        }
        let killer = DispatchWorkItem { if proc.isRunning { proc.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        proc.waitUntilExit()
        killer.cancel()
        reader.wait()
        return collected
    }
}
