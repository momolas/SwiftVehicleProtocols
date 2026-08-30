import Foundation

/// Ordre des octets pour l'extraction d'un paramètre
public enum UnifiedByteOrder: String, Codable, Sendable {
    case bigEndian = "BigEndian"
    case littleEndian = "LittleEndian"
}

/// Bornes de validation min/max d'un paramètre
public struct UnifiedLimit: Codable, Sendable, Equatable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

/// Élément de table d'énumération textuelle
public struct UnifiedTableItem: Codable, Sendable, Equatable {
    public let name: String
    public let start: Double
    public let end: Double

    public init(name: String, start: Double, end: Double) {
        self.name = name
        self.start = start
        self.end = end
    }
}

/// Format et formule de conversion physique d'un paramètre
public enum UnifiedDataFormat: Codable, Sendable, Equatable {
    case linear(multiplier: Double, offset: Double)
    case table([UnifiedTableItem])
    case boolFlag(posName: String?, negName: String?)
    case stringVal(encoding: String)
    case hexDump
    case binary
    case identical

    enum CodingKeys: String, CodingKey {
        case type, multiplier, offset, items, posName, negName, encoding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "Linear":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            let offset = try container.decode(Double.self, forKey: .offset)
            self = .linear(multiplier: multiplier, offset: offset)
        case "Table":
            let items = try container.decode([UnifiedTableItem].self, forKey: .items)
            self = .table(items)
        case "Bool":
            let posName = try container.decodeIfPresent(String.self, forKey: .posName)
            let negName = try container.decodeIfPresent(String.self, forKey: .negName)
            self = .boolFlag(posName: posName, negName: negName)
        case "String":
            let enc = try container.decode(String.self, forKey: .encoding)
            self = .stringVal(encoding: enc)
        case "HexDump":
            self = .hexDump
        case "Binary":
            self = .binary
        default:
            self = .identical
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .linear(let multiplier, let offset):
            try container.encode("Linear", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
            try container.encode(offset, forKey: .offset)
        case .table(let items):
            try container.encode("Table", forKey: .type)
            try container.encode(items, forKey: .items)
        case .boolFlag(let posName, let negName):
            try container.encode("Bool", forKey: .type)
            try container.encodeIfPresent(posName, forKey: .posName)
            try container.encodeIfPresent(negName, forKey: .negName)
        case .stringVal(let encoding):
            try container.encode("String", forKey: .type)
            try container.encode(encoding, forKey: .encoding)
        case .hexDump:
            try container.encode("HexDump", forKey: .type)
        case .binary:
            try container.encode("Binary", forKey: .type)
        case .identical:
            try container.encode("Identical", forKey: .type)
        }
    }
}

/// Définition d'un paramètre unitaire (Bitfield, signal, état)
public struct UnifiedParameter: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let unit: String
    public let startBit: Int
    public let lengthBits: Int
    public let byteOrder: UnifiedByteOrder
    public let dataFormat: UnifiedDataFormat
    public let validBounds: UnifiedLimit?

    public init(
        name: String,
        unit: String = "",
        startBit: Int,
        lengthBits: Int,
        byteOrder: UnifiedByteOrder = .bigEndian,
        dataFormat: UnifiedDataFormat = .identical,
        validBounds: UnifiedLimit? = nil
    ) {
        self.name = name
        self.unit = unit
        self.startBit = startBit
        self.lengthBits = lengthBits
        self.byteOrder = byteOrder
        self.dataFormat = dataFormat
        self.validBounds = validBounds
    }

    enum CodingKeys: String, CodingKey {
        case name, unit
        case startBit = "start_bit"
        case lengthBits = "length_bits"
        case byteOrder = "byte_order"
        case dataFormat = "data_format"
        case validBounds = "valid_bounds"
    }
}

/// Définition d'un service de diagnostic (requête/réponse, télémétrie, actionneur, routine)
public struct UnifiedService: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let payloadHex: String
    public let inputParams: [UnifiedParameter]
    public let outputParams: [UnifiedParameter]

    public init(
        name: String,
        description: String = "",
        payloadHex: String,
        inputParams: [UnifiedParameter] = [],
        outputParams: [UnifiedParameter] = []
    ) {
        self.name = name
        self.description = description
        self.payloadHex = payloadHex
        self.inputParams = inputParams
        self.outputParams = outputParams
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case payloadHex = "payload"
        case inputParams = "input_params"
        case outputParams = "output_params"
    }
}

/// Code défaut diagnostique (DTC)
public struct UnifiedDTC: Codable, Sendable, Equatable, Identifiable {
    public var id: String { errorName }
    public let errorName: String
    public let summary: String
    public let description: String

    public init(errorName: String, summary: String, description: String = "") {
        self.errorName = errorName
        self.summary = summary
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case errorName = "error_name"
        case summary, description
    }
}

/// Identification de version matérielle / fournisseur ECU
public struct UnifiedPattern: Codable, Sendable, Equatable {
    public let vendor: String
    public let vendorId: String

    public init(vendor: String, vendorId: String) {
        self.vendor = vendor
        self.vendorId = vendorId
    }

    enum CodingKeys: String, CodingKey {
        case vendor
        case vendorId = "vendor_id"
    }
}

/// Variante logicielle d'un calculateur (Software Version)
public struct UnifiedVariant: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let patterns: [UnifiedPattern]
    public let errors: [UnifiedDTC]
    public let downloads: [UnifiedService]
    public let actuations: [UnifiedService]
    public let adjustments: [UnifiedService]
    public let functions: [UnifiedService]

    public init(
        name: String,
        description: String = "",
        patterns: [UnifiedPattern] = [],
        errors: [UnifiedDTC] = [],
        downloads: [UnifiedService] = [],
        actuations: [UnifiedService] = [],
        adjustments: [UnifiedService] = [],
        functions: [UnifiedService] = []
    ) {
        self.name = name
        self.description = description
        self.patterns = patterns
        self.errors = errors
        self.downloads = downloads
        self.actuations = actuations
        self.adjustments = adjustments
        self.functions = functions
    }
}

/// Paramètres de connexion réseau au calculateur
public struct UnifiedConnection: Codable, Sendable, Equatable {
    public let busType: String
    public let baudrate: Int
    public let txId: String
    public let rxId: String
    public let protocolName: String

    public init(busType: String, baudrate: Int, txId: String, rxId: String, protocolName: String) {
        self.busType = busType
        self.baudrate = baudrate
        self.txId = txId
        self.rxId = rxId
        self.protocolName = protocolName
    }

    enum CodingKeys: String, CodingKey {
        case busType = "bus_type"
        case baudrate
        case txId = "tx_id"
        case rxId = "rx_id"
        case protocolName = "protocol"
    }
}

/// Racine du Profil Diagnostique Déclaratif Unifié (OVD Specification)
public struct UnifiedECUProfile: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let connections: [UnifiedConnection]
    public let variants: [UnifiedVariant]

    public init(
        name: String,
        description: String = "",
        connections: [UnifiedConnection] = [],
        variants: [UnifiedVariant] = []
    ) {
        self.name = name
        self.description = description
        self.connections = connections
        self.variants = variants
    }
}
