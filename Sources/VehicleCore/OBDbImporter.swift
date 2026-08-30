import Foundation

/// Modèle de données pour les fichiers de signaux OBDb (`signalsets/v3`)
public struct OBDbFormat: Codable, Sendable {
    public let bytes: Int?
    public let bit: Int?
    public let bitmask: String?
    public let offset: Double?
    public let scale: Double?
    public let unit: String?
    public let signed: Bool?

    public init(
        bytes: Int? = nil,
        bit: Int? = nil,
        bitmask: String? = nil,
        offset: Double? = nil,
        scale: Double? = nil,
        unit: String? = nil,
        signed: Bool? = nil
    ) {
        self.bytes = bytes
        self.bit = bit
        self.bitmask = bitmask
        self.offset = offset
        self.scale = scale
        self.unit = unit
        self.signed = signed
    }
}

public struct OBDbSignal: Codable, Sendable {
    public let id: String
    public let name: String
    public let path: String?
    public let description: String?
    public let fmt: OBDbFormat

    public init(
        id: String,
        name: String,
        path: String? = nil,
        description: String? = nil,
        fmt: OBDbFormat
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.description = description
        self.fmt = fmt
    }
}

public struct OBDbCommand: Codable, Sendable {
    public let hdr: String
    public let cmd: String
    public let freq: Double?
    public let signals: [OBDbSignal]

    public init(
        hdr: String,
        cmd: String,
        freq: Double? = nil,
        signals: [OBDbSignal]
    ) {
        self.hdr = hdr
        self.cmd = cmd
        self.freq = freq
        self.signals = signals
    }
}

public struct OBDbSignalset: Codable, Sendable {
    public let diagnosticLevel: String?
    public let commands: [OBDbCommand]

    public init(
        diagnosticLevel: String? = nil,
        commands: [OBDbCommand]
    ) {
        self.diagnosticLevel = diagnosticLevel
        self.commands = commands
    }
}

/// Convertisseur haute performance des signalsets OBDb vers `UnifiedECUProfile` et `Profile`
public enum OBDbImporter: Sendable {

    /// Décode et convertit un fichier JSON OBDb (`signalsets/v3`) vers `UnifiedECUProfile`
    public static func convert(
        jsonData: Data,
        vehicleName: String,
        profileId: String,
        protocolType: String = "CAN_UDS"
    ) throws -> UnifiedECUProfile {
        let decoder = JSONDecoder()
        let signalset = try decoder.decode(OBDbSignalset.self, from: jsonData)
        return convert(signalset: signalset, vehicleName: vehicleName, profileId: profileId, protocolType: protocolType)
    }

    /// Convertit une structure `OBDbSignalset` en `UnifiedECUProfile`
    public static func convert(
        signalset: OBDbSignalset,
        vehicleName: String,
        profileId: String,
        protocolType: String = "CAN_UDS"
    ) -> UnifiedECUProfile {
        var connections: [UnifiedConnection] = []
        var headersSeen: Set<String> = []
        var downloadServices: [UnifiedService] = []

        for cmd in signalset.commands {
            let cleanHdr = cmd.hdr.replacingOccurrences(of: "0x", with: "").uppercased()
            if !headersSeen.contains(cleanHdr) {
                headersSeen.insert(cleanHdr)
                let txVal = UInt32(cleanHdr, radix: 16) ?? 0x7E0
                let rxHex = String(format: "%03X", txVal + 8)
                connections.append(
                    UnifiedConnection(
                        busType: "CAN",
                        baudrate: 500000,
                        txId: "0x\(cleanHdr)",
                        rxId: "0x\(rxHex)",
                        protocolName: protocolType
                    )
                )
            }

            var outputParams: [UnifiedParameter] = []
            var currentByteOffset = 0

            for sig in cmd.signals {
                let bytesCount = sig.fmt.bytes ?? 1
                let lengthBits = bytesCount * 8
                let startBit = currentByteOffset * 8 + (sig.fmt.bit ?? 0)

                let multiplier = sig.fmt.scale ?? 1.0
                let offset = sig.fmt.offset ?? 0.0

                let dataFormat: UnifiedDataFormat
                if multiplier == 1.0 && offset == 0.0 && (sig.fmt.unit == nil || sig.fmt.unit?.isEmpty == true) {
                    dataFormat = .identical
                } else {
                    dataFormat = .linear(multiplier: multiplier, offset: offset)
                }

                let param = UnifiedParameter(
                    name: sig.name.isEmpty ? sig.id : sig.name,
                    unit: sig.fmt.unit ?? "",
                    startBit: startBit,
                    lengthBits: lengthBits,
                    byteOrder: .bigEndian,
                    dataFormat: dataFormat
                )
                outputParams.append(param)
                currentByteOffset += bytesCount
            }

            let service = UnifiedService(
                name: "Cmd_\(cmd.cmd)",
                description: "OBDb Command \(cmd.cmd)",
                payloadHex: cmd.cmd,
                inputParams: [],
                outputParams: outputParams
            )
            downloadServices.append(service)
        }

        if connections.isEmpty {
            connections.append(
                UnifiedConnection(
                    busType: "CAN",
                    baudrate: 500000,
                    txId: "0x7E0",
                    rxId: "0x7E8",
                    protocolName: protocolType
                )
            )
        }

        let variant = UnifiedVariant(
            name: "\(profileId)_Variant",
            description: "Signalset importé pour \(vehicleName)",
            patterns: [
                UnifiedPattern(vendor: vehicleName, vendorId: profileId)
            ],
            errors: [],
            downloads: downloadServices,
            actuations: [],
            adjustments: [],
            functions: []
        )

        return UnifiedECUProfile(
            name: vehicleName,
            description: "Profil généré automatiquement depuis le catalogue OBDb",
            connections: connections,
            variants: [variant]
        )
    }

    /// Convertit directement un JSON OBDb en `Profile` RAPIDTRUTH
    public static func convertToProfile(
        jsonData: Data,
        vehicleName: String,
        profileId: String
    ) throws -> Profile {
        let unified = try convert(jsonData: jsonData, vehicleName: vehicleName, profileId: profileId)
        return UnifiedProfileConverter.toLegacyProfile(unified: unified, id: profileId)
    }
}
