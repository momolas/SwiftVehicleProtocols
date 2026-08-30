import Foundation
import VehicleCore

public protocol VehicleInterface: AnyObject, Sendable {
    func sendRawCAN(id: UInt32, data: Data, bus: UInt8) async throws
    func sendDiagnosticRequest(_ requestHex: String, timeout: TimeInterval) async throws -> String
    func setTarget(txID: String, rxID: String?) async throws
}

public extension VehicleInterface {
    func sendRawCAN(id: UInt32, data: Data, bus: UInt8) async throws {
        // Optionnel pour les interfaces ne supportant que la couche diagnostique (ex: ELM327)
    }
}
