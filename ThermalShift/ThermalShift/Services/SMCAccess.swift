import Foundation
import IOKit

/// Reads temperature keys from Apple's System Management Controller (SMC).
/// On Intel Macs the `TC0P` key exposes the CPU proximity temperature,
/// which is the PECI (Platform Environment Control Interface) reference.
nonisolated enum SMCAccess {

    private static var connection: io_connect_t = 0
    private static var opened = false

    private static func connect() -> io_connect_t? {
        if opened {
            return connection
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }

        var conn: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else { return nil }

        connection = conn
        opened = true
        return conn
    }

    static func readTemperature(keys: [String] = ["TC0P", "TC0H", "TC0E", "TC0C", "TC0D"]) -> Double? {
        for key in keys {
            if let value = readInteger(bigEndianKey: keyCode(key)) {
                return value
            }
        }
        return nil
    }

    static func readTemperature(key: String) -> Double? {
        guard let conn = connect() else { return nil }
        return readKey(conn: conn, key: key)
    }

    private static func keyCode(_ key: String) -> UInt32 {
        let bytes = Array(key.utf8)
        guard bytes.count == 4 else { return 0 }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    private static func readInteger(bigEndianKey: UInt32) -> Double? {
        guard let conn = connect() else { return nil }
        return readKeyBinary(conn: conn, key: bigEndianKey)
    }

    private static func readKey(conn: io_connect_t, key: String) -> Double? {
        readKeyBinary(conn: conn, key: keyCode(key))
    }

    private static func readKeyBinary(conn: io_connect_t, key: UInt32) -> Double? {
        let selector: UInt32 = 2 // kSMCHandleYPCEvent

        struct SMCKeyData {
            var key: UInt32 = 0
            var vers: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
            var pLimitData: (UInt16, UInt16, UInt16, UInt16) = (0, 0, 0, 0)
            var keyInfo: (UInt8, UInt8, UInt8, UInt8, UInt32, UInt32, UInt16, UInt16) = (0, 0, 0, 0, 0, 0, 0, 0)
            var result: UInt8 = 0
            var status: UInt8 = 0
            var data8: UInt8 = 0
            var data32: UInt32 = 0
            var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0
            )
        }

        var input = SMCKeyData()
        input.key = key.bigEndian
        input.data8 = 32 // request full 32-byte data block

        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.size

        let result = IOConnectCallStructMethod(
            conn,
            selector,
            &input,
            MemoryLayout<SMCKeyData>.size,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess else { return nil }

        return decodeData(
            bytes: withUnsafeBytes(of: &output.bytes) { Array($0) },
            dataType: output.data32
        )
    }

    // Data types commonly used for temperatures:
    //   sp78  – signed 7.8 fixed point (°C, most temperature keys)
    //   flt   – 32-bit float
    //   ui8/ui16 – unsigned integer
    private static func decodeData(bytes: [UInt8], dataType: UInt32) -> Double? {
        let datatype = String(
            bytes: [
                UInt8((dataType >> 24) & 0xFF),
                UInt8((dataType >> 16) & 0xFF),
                UInt8((dataType >> 8) & 0xFF),
                UInt8(dataType & 0xFF)
            ],
            encoding: .ascii
        ) ?? ""

        switch datatype {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            let signed = Int16(bitPattern: raw)
            return Double(signed) / 256.0
        case "flt ", "flt":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return Double(Float(bitPattern: bits))
        case "ui8":
            return bytes.isEmpty ? nil : Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        default:
            return nil
        }
    }
}