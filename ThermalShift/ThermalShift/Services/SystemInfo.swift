import Foundation
import AppKit

nonisolated struct SystemInfo: Equatable {
    var machineName: String
    var modelIdentifier: String
    var modelName: String
    var cpuName: String
    var memoryGB: Int
    var gpuList: [String]
    var storageDescription: String
    var osVersionString: String
    var modelImagePath: String?

    var isEmpty: Bool {
        cpuName.isEmpty && gpuList.isEmpty
    }
}

nonisolated enum SystemInfoProvider {

    static func syncInfo() -> SystemInfo {
        let cpu = sysctlString("machdep.cpu.brand_string")
        let identifier = sysctlString("hw.model")
        let memoryBytes = sysctlInt64("hw.memsize")
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let build = sysctlString("kern.osversion")

        let family = family(for: identifier)
        let name = visibleName(for: identifier, family: family)

        return SystemInfo(
            machineName: family,
            modelIdentifier: identifier,
            modelName: name,
            cpuName: cpu,
            memoryGB: Int(memoryBytes / 1_000_000_000),
            gpuList: [],
            storageDescription: "",
            osVersionString: "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion) (\(build))",
            modelImagePath: modelImagePath(for: name)
        )
    }

    static func enrichWithHardware(_ info: SystemInfo) async -> SystemInfo {
        var updated = info

        if let hardware = try? await jsonFromSystemProfiler("SPHardwareDataType"),
           let overview = (hardware["SPHardwareDataType"] as? [[String: Any]])?.first,
           let memory = overview["physical_memory"] as? String {
            updated.memoryGB = parseMemoryGB(memory)
        }

        if let displays = try? await jsonFromSystemProfiler("SPDisplaysDataType") {
            let gpus = (displays["SPDisplaysDataType"] as? [[String: Any]]) ?? []
            updated.gpuList = gpus.compactMap { gpu in
                let chip = gpu["sppci_model"] as? String ?? gpu["_name"] as? String ?? ""
                let vram = gpu["spdisplays_vram_shared"] as? String
                    ?? gpu["_spdisplays_vram"] as? String
                if let vram {
                    return "\(chip) · \(vram)"
                }
                return chip
            }
        }

        if let storage = try? await jsonFromSystemProfiler("SPNVMeDataType"),
           let drives = storage["SPNVMeDataType"] as? [[String: Any]],
           let firstDrive = drives.first {
            var name = (firstDrive["_name"] as? String) ?? ""
            var size = (firstDrive["size"] as? String) ?? ""
            if let items = firstDrive["_items"] as? [[String: Any]], let device = items.first {
                name = (device["_name"] as? String) ?? name
                size = (device["size"] as? String) ?? size
            }
            let linkSpeed = (firstDrive["spnvme_linkspeed"] as? String) ?? ""
            updated.storageDescription = "\(name) · \(size) · NVMe \(linkSpeed)"
        }

        if updated.storageDescription.isEmpty,
           let storage = try? await jsonFromSystemProfiler("SPSerialATADataType"),
           let drives = storage["SPSerialATADataType"] as? [[String: Any]],
           let first = drives.first {
            var name = (first["_name"] as? String) ?? ""
            if let items = first["_items"] as? [[String: Any]], let device = items.first {
                name = (device["_name"] as? String) ?? name
            }
            let size = (first["size"] as? String) ?? ""
            updated.storageDescription = "\(name) · \(size)"
        }

        return updated
    }

    // MARK: - Model identification

    private static func family(for identifier: String) -> String {
        if identifier.hasPrefix("Macmini") { return "Mac mini" }
        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
        if identifier.hasPrefix("MacBook") { return "MacBook" }
        if identifier.hasPrefix("iMac") { return "iMac" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro" }
        if identifier.hasPrefix("MacStudio") { return "Mac Studio" }
        return identifier
    }

    private static func visibleName(for identifier: String, family: String) -> String {
        switch identifier {
        case "Macmini8,1": return "Mac mini (2018)"
        case "Macmini9,1": return "Mac mini (2020)"
        case "Macmini7,1": return "Mac mini (2014)"
        case "Macmini6,1", "Macmini6,2": return "Mac mini (2012)"
        case "MacBookPro15,1", "MacBookPro15,2",
             "MacBookPro15,3", "MacBookPro15,4": return "MacBook Pro (2018–2019)"
        case "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3",
             "MacBookPro16,4": return "MacBook Pro (2019–2020)"
        case "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3": return "MacBook Pro (2017)"
        case "MacBookAir8,1", "MacBookAir8,2": return "MacBook Air (2018–2019)"
        case "iMac18,1", "iMac18,2", "iMac18,3": return "iMac (2017)"
        case "iMacPro1,1": return "iMac Pro (2017)"
        case "MacPro7,1": return "Mac Pro (2019)"
        default: return family
        }
    }

    private static func yearFrom(_ name: String) -> String {
        guard let range = name.range(of: #"\((20\d\d)"#, options: .regularExpression) else {
            return ""
        }
        return String(name[range.lowerBound...].dropFirst().dropLast())
    }

    // MARK: - Model image (system artwork, like About This Mac)

    private static func modelImagePath(for name: String) -> String? {
        let base = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources"
        let year = yearFrom(name)
        var candidates: [String] = []

        if name.hasPrefix("Mac mini") {
            if !year.isEmpty { candidates.append("com.apple.macmini-\(year).icns") }
            candidates.append("com.apple.macmini.icns")
        } else if name.hasPrefix("MacBook Pro") {
            candidates.append("com.apple.macbookpro-15-unibody.icns")
        } else if name.hasPrefix("MacBook Air") {
            candidates.append("com.apple.macbookair.icns")
        } else if name.hasPrefix("iMac") {
            candidates.append("com.apple.imac-aluminum-24.icns")
            candidates.append("com.apple.imac.icns")
        } else if name.hasPrefix("Mac Pro") {
            candidates.append("com.apple.macpro.icns")
        } else {
            return nil
        }

        for file in candidates {
            let path = "\(base)/\(file)"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func parseMemoryGB(_ value: String) -> Int {
        let cleaned = value.replacingOccurrences(of: "GB", with: "").trimmingCharacters(in: .whitespaces)
        return Int(Double(cleaned) ?? 8)
    }

    private static func sysctlString(_ key: String) -> String {
        var size = 0
        sysctlbyname(key, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(key, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private static func sysctlInt64(_ key: String) -> Int64 {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        sysctlbyname(key, &value, &size, nil, 0)
        return value
    }

    private static func jsonFromSystemProfiler(_ dataType: String) async throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", dataType]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}