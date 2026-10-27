import CoreLocation
import Foundation

enum DemoRoutes {
    static let origin = CLLocationCoordinate2D(latitude: 40.2171, longitude: -74.7429)
    static let destination = CLLocationCoordinate2D(latitude: 40.3431, longitude: -74.6514)
    static let originName = "New Jersey State House"
    static let destinationName = "Princeton University"
    static let incidentCoordinate = CLLocationCoordinate2D(latitude: 40.279, longitude: -74.683)

    static func routes() -> [NavigationRoute] {
        let fastest = Geographic.segments(from: [
            origin, CLLocationCoordinate2D(latitude: 40.238, longitude: -74.720), CLLocationCoordinate2D(latitude: 40.260, longitude: -74.696),
            CLLocationCoordinate2D(latitude: 40.279, longitude: -74.683), CLLocationCoordinate2D(latitude: 40.300, longitude: -74.668),
            CLLocationCoordinate2D(latitude: 40.320, longitude: -74.658), destination
        ], roadName: "US 1")
        let balanced = Geographic.segments(from: [
            origin, CLLocationCoordinate2D(latitude: 40.235, longitude: -74.746), CLLocationCoordinate2D(latitude: 40.255, longitude: -74.735),
            CLLocationCoordinate2D(latitude: 40.286, longitude: -74.711), CLLocationCoordinate2D(latitude: 40.316, longitude: -74.679), destination
        ], roadName: "Route 27")
        let lower = Geographic.segments(from: [
            origin, CLLocationCoordinate2D(latitude: 40.225, longitude: -74.760), CLLocationCoordinate2D(latitude: 40.244, longitude: -74.755),
            CLLocationCoordinate2D(latitude: 40.273, longitude: -74.744), CLLocationCoordinate2D(latitude: 40.300, longitude: -74.722),
            CLLocationCoordinate2D(latitude: 40.323, longitude: -74.688), destination
        ], roadName: "Province Line Rd")
        return [
            seeded(kind: .fastest, name: "US 1 North", minutes: 18, miles: 11.2, segments: fastest),
            seeded(kind: .balanced, name: "Route 27", minutes: 20, miles: 11.8, segments: balanced),
            seeded(kind: .lowerExposure, name: "Province Line Road", minutes: 22, miles: 12.4, segments: lower)
        ]
    }

    static func incidentDetour(from location: CLLocationCoordinate2D) -> NavigationRoute {
        let points = [
            location,
            CLLocationCoordinate2D(latitude: location.latitude + 0.006, longitude: location.longitude - 0.010),
            CLLocationCoordinate2D(latitude: 40.286, longitude: -74.711),
            CLLocationCoordinate2D(latitude: 40.316, longitude: -74.679),
            destination
        ]
        let segments = Geographic.segments(from: points, roadName: "Demo detour")
        let instructions = [
            RouteInstruction(text: "Turn left onto the alternate route", coordinate: points[1]),
            RouteInstruction(text: "Continue on the detour", coordinate: points[2]),
            RouteInstruction(text: "Bear right toward Princeton University", coordinate: points[3])
        ]
        return NavigationRoute(id: UUID(), kind: .balanced, name: "Crash detour", expectedTravelTime: 18 * 60,
                               distanceMeters: segments.reduce(0) { $0 + $1.distanceMeters }, segments: segments,
                               instructions: instructions,
                               exposure: RouteExposure(score: 0, level: .moderate, severeCrashExposure: 0,
                                                       intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0,
                                                       pedestrianExposure: 0, cyclistExposure: 0, segments: []), isSampleData: true)
    }

    private static func seeded(kind: RouteKind, name: String, minutes: Int, miles: Double, segments: [GeographicSegment]) -> NavigationRoute {
        let instructions = kind == .fastest ? [
            RouteInstruction(text: "Continue north on US 1", coordinate: segments[3].end),
            RouteInstruction(text: "Keep right toward Princeton University", coordinate: segments[5].end)
        ] : []
        return NavigationRoute(id: UUID(), kind: kind, name: name, expectedTravelTime: Double(minutes * 60), distanceMeters: miles * 1_609.344, segments: segments, instructions: instructions, exposure: RouteExposure(score: 0, level: .moderate, severeCrashExposure: 0, intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: []), isSampleData: true)
    }
}

enum ShowcaseMotion {
    static func metersPerSecond(for route: NavigationRoute) -> Double {
        let distance = route.segments.reduce(0) { $0 + $1.distanceMeters }
        return min(20.1, max(6.7, distance / max(route.expectedTravelTime, 1)))
    }

    static func nextProgress(on segments: [GeographicSegment], from progress: Double, speed: Double, seconds: Double) -> Double {
        let distance = segments.reduce(0) { $0 + $1.distanceMeters }
        guard distance > 0 else { return 1 }
        return min(1, progress + speed * seconds / distance)
    }
}
