import Foundation
import Observation

/// Niveau de priorité des opérations accédant à l'interface véhicule / Panda.
public enum BusPriority: Int, Comparable, Sendable {
    case background = 0
    case interactive = 1
    case criticalExclusive = 2

    public static func < (lhs: BusPriority, rhs: BusPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Coordinateur d'accès au bus pour arbitrer et synchroniser les requêtes entre les différents modules
/// (Diagnostic, Sampler temps réel, Fuzzer, Actuateurs, Flashing).
@MainActor
@Observable
public final class BusCoordinator: Sendable {
    public static let shared = BusCoordinator()

    public private(set) var activeSessionName: String? = nil
    public private(set) var activePriority: BusPriority = .background
    public private(set) var isBusy: Bool = false

    private var lockHolderCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Tente ou attend l'acquisition du bus pour une opération critique.
    public func acquire(priority: BusPriority = .interactive, name: String) async {
        while isBusy && priority <= activePriority {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isBusy = true
        activePriority = priority
        activeSessionName = name
        lockHolderCount += 1
    }

    /// Libère l'accès au bus et réveille les tâches en attente.
    public func release() {
        guard lockHolderCount > 0 else { return }
        lockHolderCount -= 1

        if lockHolderCount == 0 {
            isBusy = false
            activeSessionName = nil
            activePriority = .background

            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            }
        }
    }

    /// Exécute un bloc asynchrone avec réservation exclusive du bus.
    public func withExclusiveAccess<T: Sendable>(
        priority: BusPriority = .interactive,
        name: String,
        operation: @MainActor () async throws -> T
    ) async throws -> T {
        await acquire(priority: priority, name: name)
        defer {
            release()
        }
        return try await operation()
    }
}
