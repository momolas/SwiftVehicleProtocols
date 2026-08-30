import Foundation
import VehicleCore

public enum SamplingRate: String, Sendable, CaseIterable, Codable {
    case fast = "10 Hz"
    case normal = "2 Hz"
    case slow = "0.5 Hz"

    public var tickDivider: Int {
        switch self {
        case .fast: return 1
        case .normal: return 5
        case .slow: return 20
        }
    }

    public var intervalMs: Int {
        switch self {
        case .fast: return 100
        case .normal: return 500
        case .slow: return 2000
        }
    }
}

public enum MultiRateSampler: Sendable {
    public static func defaultSamplingRate(for pid: PidDef) -> SamplingRate {
        switch pid.category {
        case .rpm, .speed, .engine, .pressure, .air, .brakes:
            return .fast
        case .fuel, .electrical, .battery, .hybrid, .transmission, .emissions:
            return .normal
        case .temperature, .climate, .airbag, .lighting, .body, .diagnostics, .other:
            return .slow
        }
    }
}
