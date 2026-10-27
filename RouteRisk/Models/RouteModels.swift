import CoreLocation
import Foundation

enum TravelMode: String, CaseIterable, Identifiable {
    case driving, cycling, walking
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .driving: return "car.fill"; case .cycling: return "bicycle"; case .walking: return "figure.walk" }
    }
}

enum DeparturePeriod: String, CaseIterable, Identifiable {
    case daytime, evening, nighttime
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { self == .nighttime ? "moon.stars.fill" : self == .evening ? "sunset.fill" : "sun.max.fill" }
}

enum ExposureLevel: Int, CaseIterable, Comparable {
    case lower, moderate, elevated, high
    static func < (lhs: ExposureLevel, rhs: ExposureLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    var title: String { switch self { case .lower: return "Lower"; case .moderate: return "Moderate"; case .elevated: return "Elevated"; case .high: return "High" } }
    var symbol: String { switch self { case .lower: return "checkmark.circle.fill"; case .moderate: return "equal.circle.fill"; case .elevated: return "exclamationmark.circle.fill"; case .high: return "exclamationmark.triangle.fill" } }
}

enum RouteKind: String, CaseIterable, Identifiable {
    case fastest, balanced, lowerExposure
    var id: String { rawValue }
    var title: String { switch self { case .fastest: return "Fastest"; case .balanced: return "Balanced"; case .lowerExposure: return "Lower Exposure" } }
}

enum RouteEndpoint: Equatable {
    case origin
    case destination
    case stop
}

struct TripStop {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct GeographicSegment: Identifiable {
    let id = UUID()
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let roadName: String
    var distanceMeters: CLLocationDistance { Geographic.distance(from: start, to: end) }
}

struct SegmentExposure: Identifiable {
    let id: UUID
    let segment: GeographicSegment
    let score: Double
    let crashCount: Int
    let severeCrashCount: Int
    let nighttimeSensitive: Bool
    let level: ExposureLevel
}

struct RouteExposure {
    let score: Double
    let level: ExposureLevel
    let severeCrashExposure: Double
    let intersectionCount: Int
    let elevatedMiles: Double
    let nighttimeAdjustmentMiles: Double
    let pedestrianExposure: Double
    let cyclistExposure: Double
    let segments: [SegmentExposure]
}

struct RouteInstruction {
    let text: String
    let coordinate: CLLocationCoordinate2D
}

struct NavigationRoute: Identifiable {
    let id: UUID
    var kind: RouteKind
    let name: String
    let expectedTravelTime: TimeInterval
    let distanceMeters: CLLocationDistance
    let segments: [GeographicSegment]
    let instructions: [RouteInstruction]
    var exposure: RouteExposure
    var isSampleData: Bool

    var minutes: Int { Int((expectedTravelTime / 60).rounded()) }
    var miles: Double { distanceMeters / 1_609.344 }
}

struct RankedRoute: Identifiable {
    let route: NavigationRoute
    let rank: Int
    let preferenceCost: Double
    var id: UUID { route.id }
}
