import Foundation
import VehicleCore

public actor SimulatorEngine: VehicleInterface {
    private var currentTx: String = "7E0"
    private var currentRx: String = "7E8"

    public init() {}

    public func setTarget(txID: String, rxID: String?) async throws {
        self.currentTx = txID
        if let rxID {
            self.currentRx = rxID
        } else {
            let txVal = UInt32(txID, radix: 16) ?? 0x7E0
            self.currentRx = String(format: "%X", txVal + 8)
        }
    }

    public func sendRawCAN(id: UInt32, data: Data, bus: UInt8) async throws {
        // Mock sending raw frame
    }

    public func sendDiagnosticRequest(_ requestHex: String, timeout: TimeInterval = 2.0) async throws -> String {
        let clean = requestHex.replacing( " ", with: "").uppercased()

        // 1. Session request (10)
        if clean.hasPrefix("10") {
            return "50" + clean.dropFirst(2) + "003201F4"
        }

        // 2. ECU Reset (11)
        if clean.hasPrefix("11") {
            return "51" + clean.dropFirst(2)
        }

        // 3. Clear DTCs (14)
        if clean.hasPrefix("14") {
            return "54"
        }

        // 4. Read DTC Info (19)
        if clean.hasPrefix("19") {
            return "5902FF0102002F"
        }

        // 5. Read Data By Identifier (22)
        if clean.hasPrefix("22") {
            let did = String(clean.dropFirst(2).prefix(4))
            if did == "F190" {
                // Mock VIN: "VF1JM0G0D12345678"
                return "62F1905646314A4D304730443132333435363738"
            }
            return "62" + did + "00AA"
        }

        // 6. Read Local Identifier (21 XX)
        if clean.hasPrefix("21") {
            let lid = String(clean.dropFirst(2).prefix(2))
            if lid == "00" {
                return "61 00 01 00 00 00 00 00" // UCH config mock
            } else if lid == "01" {
                return "61 01 00 01 01 00 00 00" // TdB config mock
            } else if lid == "0C" || lid == "A0" {
                return "61 A0 0B B8" // 750 RPM
            }
            return "61" + lid + "0000"
        }

        // 7. Write Local Identifier (3B XX)
        if clean.hasPrefix("3B") {
            let lid = String(clean.dropFirst(2).prefix(2))
            return "7B" + lid
        }

        // 8. Routine Control / Actuators (30 / 31)
        if clean.hasPrefix("30") || clean.hasPrefix("31") {
            return "7101"
        }

        // 9. OBD-II Mode 01
        if clean.hasPrefix("01") {
            let pid = String(clean.dropFirst(2).prefix(2))
            if pid == "0C" {
                return "41 0C 0B B8" // 750 RPM
            } else if pid == "0D" {
                return "41 0D 32" // 50 km/h
            } else if pid == "05" {
                return "41 05 78" // 80°C
            }
            return "41" + pid + "00"
        }

        // Default positive response
        return "60" + clean
    }
}
