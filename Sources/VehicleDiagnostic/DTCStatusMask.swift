import Foundation

/// Masque d'état de code défaut conforme à la norme ISO 14229-1 (UDS) et ISO 14230 (KWP2000).
public struct DTCStatusMask: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Bit 0: Le dernier test d'autodiagnostic a échoué (DTC actif / présent)
    public static let testFailed = DTCStatusMask(rawValue: 1 << 0)

    /// Bit 1: Le test a échoué au cours du cycle de conduite / fonctionnement actuel
    public static let testFailedThisOperationCycle = DTCStatusMask(rawValue: 1 << 1)

    /// Bit 2: Défaut en cours de confirmation / fugitif (Pending DTC)
    public static let pendingDTC = DTCStatusMask(rawValue: 1 << 2)

    /// Bit 3: Défaut validé et enregistré en mémoire non volatile (Confirmed DTC)
    public static let confirmedDTC = DTCStatusMask(rawValue: 1 << 3)

    /// Bit 4: Le cycle de test n'a pas été complété depuis le dernier effacement des défauts
    public static let testNotCompletedSinceLastClear = DTCStatusMask(rawValue: 1 << 4)

    /// Bit 5: Le test a échoué au moins une fois depuis le dernier effacement
    public static let testFailedSinceLastClear = DTCStatusMask(rawValue: 1 << 5)

    /// Bit 6: Le test n'est pas encore terminé sur ce cycle de fonctionnement
    public static let testNotCompletedThisOperationCycle = DTCStatusMask(rawValue: 1 << 6)

    /// Bit 7: Allumage du voyant au tableau de bord demandé (MIL / Voyant Clé / Moteur)
    public static let warningIndicatorRequested = DTCStatusMask(rawValue: 1 << 7)

    /// Tous les drapeaux combinés
    public static let all: DTCStatusMask = [
        .testFailed,
        .testFailedThisOperationCycle,
        .pendingDTC,
        .confirmedDTC,
        .testNotCompletedSinceLastClear,
        .testFailedSinceLastClear,
        .testNotCompletedThisOperationCycle,
        .warningIndicatorRequested
    ]

    /// Liste lisible des drapeaux actifs
    public var descriptions: [String] {
        var list: [String] = []
        if contains(.testFailed) { list.append("Actif (Échec)") }
        if contains(.testFailedThisOperationCycle) { list.append("Échec ce cycle") }
        if contains(.pendingDTC) { list.append("En attente") }
        if contains(.confirmedDTC) { list.append("Confirmé") }
        if contains(.testNotCompletedSinceLastClear) { list.append("Non testé depuis reset") }
        if contains(.testFailedSinceLastClear) { list.append("Échoué depuis reset") }
        if contains(.testNotCompletedThisOperationCycle) { list.append("Non testé ce cycle") }
        if contains(.warningIndicatorRequested) { list.append("Voyant requis") }
        return list
    }

    /// Résumé textuel court
    public var summary: String {
        let descs = descriptions
        return descs.isEmpty ? "Inactif / Passé" : descs.joined(separator: ", ")
    }
}

/// Représentation détaillée d'un code défaut avec son code et son statut ISO 14229 / KWP2000.
public struct DecodedDTC: Identifiable, Sendable, Codable, Hashable {
    public var id: String { code }
    public let code: String
    public let statusByte: UInt8?
    public let statusMask: DTCStatusMask?

    public init(code: String, statusByte: UInt8? = nil) {
        self.code = code
        self.statusByte = statusByte
        if let statusByte {
            self.statusMask = DTCStatusMask(rawValue: statusByte)
        } else {
            self.statusMask = nil
        }
    }
}
