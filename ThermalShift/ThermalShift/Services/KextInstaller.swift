import Foundation

/// Installs and loads the bundled VoltageShift kernel extension.
///
/// Uses `osascript` with administrator privileges so macOS shows its own
/// authentication prompt ("ThermalShift wants to make changes"), which is
/// the system message that asks the user to allow the extension.
nonisolated enum KextInstaller {

    enum InstallError: Error, LocalizedError {
        case binaryNotBundled
        case authorizationDenied
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotBundled:
                return "The extension files are not bundled with this app."
            case .authorizationDenied:
                return "Authorization was cancelled or denied."
            case .installFailed(let detail):
                return "The extension could not be loaded. \(detail)"
            }
        }
    }

    // MARK: - Locating bundled files

    static func bundledKextURL() -> URL? {
        if let url = Bundle.main.url(forResource: "VoltageShift", withExtension: "kext") {
            return url
        }
        if let resource = Bundle.main.resourceURL?
            .appendingPathComponent("VoltageShift.kext"),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }
        let devPath = "/Users/rimeri/Desktop/PROYECTOS/ThermalShift/VoltageShift.kext"
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }
        return nil
    }

    static func bundledBinaryURL() -> URL? {
        if let url = Bundle.main.url(forResource: "voltageshift", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
        let devPath = "/Users/rimeri/Desktop/PROYECTOS/ThermalShift/voltageshift"
        if FileManager.default.isExecutableFile(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }
        return nil
    }

    // MARK: - Install

    /// Copies the kext (and the CLI binary) into their system locations and
    /// asks the kernel to load them. Runs as root after the user authenticates
    /// with the standard macOS prompt.
    @discardableResult
    static func install() async throws -> Bool {
        guard let kext = bundledKextURL() else { throw InstallError.binaryNotBundled }

        let script = installScript(kextPath: kext.path)
        let success = try await runAuthorized(script: script)
        guard success else { throw InstallError.authorizationDenied }

        let loaded = await Task.detached(operation: {
            VoltageShiftCommand.kextLoaded(kextPath: "/Library/Extensions/VoltageShift.kext")
        }).value

        if !loaded {
            throw InstallError.installFailed("The kext was copied but did not load. Check Privacy & Security.")
        }
        return true
    }

    private static func installScript(kextPath: String) -> String {
        """
        /bin/rm -rf "/Library/Extensions/VoltageShift.kext"
        /bin/cp -R '\(kextPath)' "/Library/Extensions/VoltageShift.kext"
        /usr/sbin/chown -R root:wheel "/Library/Extensions/VoltageShift.kext"
        /bin/chmod -R 755 "/Library/Extensions/VoltageShift.kext"
        if [ -x /usr/sbin/kextutil ]; then
            /usr/sbin/kextutil "/Library/Extensions/VoltageShift.kext" 2>/dev/null
        else
            /usr/bin/touch "/System/Library/Extensions"
            /sbin/kextload "/Library/Extensions/VoltageShift.kext" 2>/dev/null
        fi
        exit 0
        """
    }

    // MARK: - Authorization (modern approach using osascript)

    private static func runAuthorized(script: String) async throws -> Bool {
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let osascript = """
        do shell script "\(escapedScript)" with administrator privileges
        """

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", osascript]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { proc in
                let status = proc.terminationStatus
                if status == 0 {
                    continuation.resume(returning: true)
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    if output.contains("User canceled") || output.contains("cancelled") {
                        continuation.resume(throwing: InstallError.authorizationDenied)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: InstallError.installFailed("Failed to start authorization: \(error)"))
            }
        }
    }
}

extension VoltageShiftCommand {
    /// Like `kextLoaded()` but checks a specific on-disk kext bundle path,
    /// matching by bundle identifier inside the returned `kextstat -l` list.
    static func kextLoaded(kextPath: String) -> Bool {
        let output = run("/usr/sbin/kextstat", arguments: ["-l"])
        if output.isEmpty {
            return FileManager.default.fileExists(atPath: kextPath)
        }
        return output.contains("com.sicreative.VoltageShift")
    }
}