import CoreLocation
import Foundation

enum CrashSeverity: Int, CaseIterable, Codable, Comparable {
    case propertyDamage = 1
    case injury = 2
    case seriousInjury = 3
    case fatal = 4

    var label: String {
        switch self {
        case .propertyDamage: return "Property damage"
        case .injury: return "Injury"
        case .seriousInjury: return "Serious injury"
        case .fatal: return "Fatal"
        }
    }

    static func < (lhs: CrashSeverity, rhs: CrashSeverity) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct CrashRecord: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let severity: CrashSeverity
    let fatal: Bool
    let injury: Bool
    let pedestrianInvolved: Bool
    let cyclistInvolved: Bool
    let roadName: String
    let intersectionName: String?
    let lightingCondition: LightingCondition
    let weatherCondition: WeatherCondition
    let speedLimit: Int
    let roadClass: RoadClass
}

enum LightingCondition: String, Codable { case daylight, dusk, darkLit, darkUnlit }
enum WeatherCondition: String, Codable { case clear, rain, snow, fog }
enum RoadClass: String, Codable { case local, arterial, highway }
