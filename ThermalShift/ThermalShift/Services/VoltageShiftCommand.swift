import Foundation

nonisolated enum VoltageShiftStatus: Equatable {
    case binaryNotFound
    case kextNotLoaded
    case kextLoaded
}

nonisolated final class PipeJournal {
    private var buffer = Data()
    private let lock = NSLock()

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}

nonisolated struct CPUInfoFromTool: Equatable {
    let baseFrequencyMHz: Int
    let maxFrequenciesMHz: [Int]
    let currentPL1: Int
    let currentPL2: Int
    let turboEnabled: Bool
    let temperature: Int
    let packagePower: Double
    let corePower: Double
    let frequencyGHz: Double
    let voltage: Double
}

/// Thin wrapper around the bundled `voltageshift` command.
nonisolated enum VoltageShiftCommand {

    static func binaryURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment["THERMALSHIFT_VOLTAGESHIFT"] {
            let candidate = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        if let bundled = Bundle.main.url(forResource: "voltageshift", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        let devPath = "/Users/rimeri/Desktop/PROYECTOS/ThermalShift/voltageshift"
        if FileManager.default.isExecutableFile(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }

        return nil
    }

    static func kextLoaded() -> Bool {
        let output = run("/usr/sbin/kextstat", arguments: ["-l"])
        return output.contains("com.sicreative.VoltageShift")
    }

    static func status() -> VoltageShiftStatus {
        guard binaryURL() != nil else { return .binaryNotFound }
        return kextLoaded() ? .kextLoaded : .kextNotLoaded
    }

    // MARK: - Info Parsing

    /// Parses `voltageshift info` output to extract CPU specs and current settings.
    static func parseInfo() -> CPUInfoFromTool? {
        guard let binary = binaryURL() else { return nil }
        let output = run(binary.path, arguments: ["info"])
        return parseInfoOutput(output)
    }

    private static func parseInfoOutput(_ output: String) -> CPUInfoFromTool? {
        var baseFreq: Int = 0
        var maxFreqs: [Int] = []
        var currentPL1: Int = 0
        var currentPL2: Int = 0
        var turboEnabled: Bool = false
        var temperature: Int = 0
        var pkgPower: Double = 0
        var corePower: Double = 0
        var freqGHz: Double = 0
        var voltage: Double = 0

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // CPU BaseFreq: 3200, CPU MaxFreq(1/2/4/6): 4600/4500/4300/4300 (mhz)
            if trimmed.contains("CPU BaseFreq:") {
                let parts = trimmed.components(separatedBy: ",")
                if let basePart = parts.first {
                    let nums = basePart.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }.filter { $0 > 0 }
                    if let first = nums.first { baseFreq = first }
                }
                if parts.count > 1 {
                    let maxPart = parts[1]
                    let maxNums = maxPart.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }.filter { $0 > 0 }
                    maxFreqs = maxNums
                }
            }

            // OC_Locked Turbo_Disabled PL1: 100W PL2: 125W
            if trimmed.contains("PL1:") && trimmed.contains("PL2:") {
                let pl1Match = firstMatch(in: trimmed, pattern: #"PL1:\s*(\d+)W"#)
                let pl2Match = firstMatch(in: trimmed, pattern: #"PL2:\s*(\d+)W"#)
                let turboMatch = firstMatch(in: trimmed, pattern: #"Turbo_(Enabled|Disabled)"#)

                if let pl1 = pl1Match { currentPL1 = Int(pl1) ?? 0 }
                if let pl2 = pl2Match { currentPL2 = Int(pl2) ?? 0 }
                turboEnabled = (turboMatch == "Enabled")
            }

            // CPU Freq: 3.2ghz, Voltage: 1.0457v, Power:pkg 33.79w /core 29.77w,Temp: 80 c
            if trimmed.contains("CPU Freq:") && trimmed.contains("Temp:") {
                if let freq = firstMatch(in: trimmed, pattern: #"Freq:\s*([\d.]+)\s*ghz"#) {
                    freqGHz = Double(freq) ?? 0
                }
                if let volt = firstMatch(in: trimmed, pattern: #"Voltage:\s*([\d.]+)v"#) {
                    voltage = Double(volt) ?? 0
                }
                if let pkg = firstMatch(in: trimmed, pattern: #"pkg\s*([\d.]+)\s*w"#) {
                    pkgPower = Double(pkg) ?? 0
                }
                if let core = firstMatch(in: trimmed, pattern: #"/core\s*([\d.]+)\s*w"#) {
                    corePower = Double(core) ?? 0
                }
                if let temp = firstMatch(in: trimmed, pattern: #"Temp:\s*(\d+)\s*c"#) {
                    temperature = Int(temp) ?? 0
                }
            }
        }

        guard baseFreq > 0 else { return nil }

        return CPUInfoFromTool(
            baseFrequencyMHz: baseFreq,
            maxFrequenciesMHz: maxFreqs,
            currentPL1: currentPL1,
            currentPL2: currentPL2,
            turboEnabled: turboEnabled,
            temperature: temperature,
            packagePower: pkgPower,
            corePower: corePower,
            frequencyGHz: freqGHz,
            voltage: voltage
        )
    }

    // MARK: - Monitor Sample

    static func monitorSample() -> VoltageShiftSample? {
        guard let binary = binaryURL(), kextLoaded() else { return nil }

        let process = Process()
        process.executableURL = binary
        process.arguments = ["mon"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let journal = PipeJournal()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            journal.append(data)
        }

        do {
            try process.run()

            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.2) {
                process.terminate()
                group.leave()
            }
            group.wait()

            pipe.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                process.terminate()
            }

            let text = String(data: journal.data, encoding: .utf8) ?? ""
            return parseMonitor(text)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
    }

    // MARK: - Monitor Parsing
    // Format: CPU Freq: 4.2ghz, Voltage: 1.3395v, Power:pkg 52.12w /core 47.17w,Temp: 89 c
    static func parseMonitor(_ output: String) -> VoltageShiftSample? {
        guard !output.contains("not running"),
              !output.lowercased().contains("can't get") else {
            return nil
        }

        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var sample: VoltageShiftSample?

        for line in lines.reversed() {
            guard
                let freq = firstMatch(in: line, pattern: #"Freq:\s*([\d.]+)\s*ghz"#),
                let temp = firstMatch(in: line, pattern: #"Temp:\s*(\d+)\s*c"#),
                let pkg = firstMatch(in: line, pattern: #"pkg\s*([\d.]+)\s*w"#)
            else { continue }

            sample = VoltageShiftSample(
                frequencyGHz: Double(freq) ?? 0,
                powerWatts: Double(pkg) ?? 0,
                temperature: Double(temp) ?? 0
            )
            break
        }
        return sample
    }

    // MARK: - Control Commands

    /// Enable or disable Turbo Boost: `voltageshift turbo 0|1`
    @discardableResult
    static func setTurbo(_ enabled: Bool) -> Bool {
        guard let binary = binaryURL() else { return false }
        let arg = enabled ? "1" : "0"
        let output = run(binary.path, arguments: ["turbo", arg])
        let success = output.contains("Modified Setting: Turbo Boost") || output.contains("Enabled")
        return success
    }

    /// Set both PL1 and PL2: `voltageshift power <PL1> <PL2>`
    @discardableResult
    static func setPowerLimits(pl1: Int, pl2: Int) -> Bool {
        guard let binary = binaryURL() else { return false }
        let output = run(binary.path, arguments: ["power", "\(pl1)", "\(pl2)"])
        let success = output.contains("Modified Setting: PL1") || output.contains("PL1(Long term):")
        return success
    }

    // MARK: - Process Helper

    static func run(_ path: String, arguments: [String]) -> String {
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

    static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[capture])
    }
}

nonisolated struct VoltageShiftSample: Equatable {
    var frequencyGHz: Double
    var powerWatts: Double
    var temperature: Double
}