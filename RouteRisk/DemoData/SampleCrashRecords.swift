import CoreLocation
import Foundation

enum SampleCrashRecords {
    private static func record(
        _ lat: Double, _ lon: Double, severity: CrashSeverity, road: String, intersection: String?,
        lighting: LightingCondition = .daylight, speed: Int = 45, pedestrian: Bool = false, cyclist: Bool = false,
        daysAgo: Int = 120
    ) -> CrashRecord {
        CrashRecord(
            id: UUID(), coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            severity: severity, fatal: severity == .fatal, injury: severity.rawValue >= CrashSeverity.injury.rawValue,
            pedestrianInvolved: pedestrian, cyclistInvolved: cyclist, roadName: road, intersectionName: intersection,
            lightingCondition: lighting, weatherCondition: .clear, speedLimit: speed,
            roadClass: speed >= 50 ? .highway : .arterial
        )
    }

    static let records: [CrashRecord] = [
        // US 1 corridor, deliberately elevated for the fastest demo option.
        record(40.238, -74.720, severity: .seriousInjury, road: "US 1", intersection: "US 1 & Bakers Basin Rd", lighting: .darkLit, speed: 55, daysAgo: 36),
        record(40.2384, -74.7195, severity: .injury, road: "US 1", intersection: "US 1 & Bakers Basin Rd", lighting: .darkLit, speed: 55, daysAgo: 71),
        record(40.260, -74.696, severity: .fatal, road: "US 1", intersection: "US 1 & Quakerbridge Rd", lighting: .darkUnlit, speed: 55, daysAgo: 182),
        record(40.279, -74.683, severity: .seriousInjury, road: "US 1", intersection: "US 1 & Scudders Mill Rd", lighting: .darkLit, speed: 50, daysAgo: 22),
        record(40.300, -74.668, severity: .injury, road: "US 1", intersection: "US 1 & Washington Rd", lighting: .darkLit, speed: 50, pedestrian: true, daysAgo: 59),
        record(40.320, -74.658, severity: .injury, road: "US 1", intersection: "US 1 & Harrison St", lighting: .daylight, speed: 45, daysAgo: 205),
        // Route 27, enough context to make the balanced route informative.
        record(40.255, -74.735, severity: .injury, road: "Route 27", intersection: "Route 27 & Franklin Corner Rd", lighting: .darkLit, speed: 40, daysAgo: 160),
        record(40.286, -74.711, severity: .injury, road: "Route 27", intersection: "Route 27 & Canal Pointe Blvd", speed: 35, cyclist: true, daysAgo: 240),
        record(40.316, -74.679, severity: .seriousInjury, road: "Route 27", intersection: "Route 27 & Alexander Rd", lighting: .darkLit, speed: 35, daysAgo: 310),
        // The quieter western demo route has a small, visible historical record.
        record(40.244, -74.755, severity: .injury, road: "Province Line Rd", intersection: "Province Line Rd & Pennington Rd", speed: 30, daysAgo: 330),
        record(40.300, -74.722, severity: .propertyDamage, road: "Cherry Valley Rd", intersection: nil, speed: 30, daysAgo: 410)
    ]
}
