import Foundation

/// Décodeur et utilitaire pour les codes défauts de diagnostic (DTC - Diagnostic Trouble Codes) selon SAE J1979 et ISO 14230
public enum DTCDecoder: Sendable {

    /// Décode un code DTC brut hexadécimal sur 2 octets (4 caractères, ex: "0102" -> "P0102")
    public static func decodeSingleDTC(_ hex: String) -> String? {
        let cleanHex = hex.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count == 4, let value = UInt16(cleanHex, radix: 16) else { return nil }

        let highByte = UInt8((value >> 8) & 0xFF)
        let lowByte = UInt8(value & 0xFF)

        let typeMap = ["P", "C", "B", "U"]
        let typeIdx = Int((highByte >> 6) & 0b11)
        let type = typeMap[typeIdx]

        let digit1 = (highByte >> 4) & 0b11
        let digit2 = highByte & 0x0F
        let digit3 = (lowByte >> 4) & 0x0F
        let digit4 = lowByte & 0x0F

        return "\(type)\(digit1)\(String(digit2, radix: 16, uppercase: true))\(String(digit3, radix: 16, uppercase: true))\(String(digit4, radix: 16, uppercase: true))"
    }

    /// Décode les drapeaux de statut d'un code défaut KWP2000 (Service 18 / 19)
    public static func decodeKwpDtcStatus(_ status: UInt8) -> String {
        var activeFlags: [String] = []
        if (status & 0x80) != 0 {
            activeFlags.append("Présent")
        } else {
            activeFlags.append("Mémorisé")
        }
        if (status & 0x40) != 0 {
            activeFlags.append("MIL demandée")
        }
        if (status & 0x20) != 0 {
            activeFlags.append("Non-confirmé")
        }
        return activeFlags.joined(separator: ", ")
    }

    /// Extrait une liste de DTCs à partir d'une réponse brute (ex: "43 01 01 02" ou "58 01 01 02 80")
    public static func decodeDTCList(from hexPayload: String) -> [String] {
        let clean = hexPayload.replacingOccurrences(of: " ", with: "")
        var dtcs: [String] = []

        // Pour OBD-II Mode 03 (43 NN ...) ou Mode 07 (47 NN ...)
        if clean.hasPrefix("43") || clean.hasPrefix("47") || clean.hasPrefix("4A") {
            let data = String(clean.dropFirst(4)) // Supprime 43 + NN
            for i in stride(from: 0, to: data.count - 3, by: 4) {
                let startIndex = data.index(data.startIndex, offsetBy: i)
                let endIndex = data.index(startIndex, offsetBy: 4)
                let dtcHex = String(data[startIndex..<endIndex])
                if dtcHex != "0000", let dtc = decodeSingleDTC(dtcHex) {
                    dtcs.append(dtc)
                }
            }
        }

        return dtcs
    }
}
