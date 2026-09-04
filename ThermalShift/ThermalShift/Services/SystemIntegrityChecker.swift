import Foundation

enum SystemIntegrityStatus: Equatable {
    case unknown
    case fullSIP
    case kextsAllowed
    case sipDisabled
}

nonisolated enum SystemIntegrityChecker {
    static func status() -> SystemIntegrityStatus {
        let output = run("/usr/bin/csrutil", arguments: ["status"])
        let lower = output.lowercased()

        if lower.contains("protection status: disabled") {
            return .sipDisabled
        }
        if lower.contains("custom configuration") {
            if lower.contains("kext signing: disabled") {
                return .kextsAllowed
            }
            return .fullSIP
        }
        if lower.contains("protection status: enabled") {
            return .fullSIP
        }
        return .unknown
    }

    private static func run(_ path: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}