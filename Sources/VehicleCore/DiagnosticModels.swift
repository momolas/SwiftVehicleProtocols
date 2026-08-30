import Foundation

public struct DTCDef: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let code: String
    public let description: String
    public let ecu: String
    public let status: String?

    public init(id: String, code: String, description: String, ecu: String, status: String? = nil) {
        self.id = id
        self.code = code
        self.description = description
        self.ecu = ecu
        self.status = status
    }
}
