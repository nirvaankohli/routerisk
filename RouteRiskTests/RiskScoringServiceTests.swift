import CoreLocation
import XCTest
@testable import RouteRisk

final class RiskScoringServiceTests: XCTestCase {
    private let routeSegment = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0), end: CLLocationCoordinate2D(latitude: 40.01, longitude: -74.0), roadName: "Test Road")

    func testPointToRoadDistanceIsSmallForNearbyPoint() {
        let distance = Geographic.pointToSegmentDistance(point: CLLocationCoordinate2D(latitude: 40.005, longitude: -73.999), start: routeSegment.start, end: routeSegment.end)
        XCTAssertLessThan(distance, 100)
    }

    func testFatalCrashContributesMoreExposureThanPropertyDamage() async {
        let fatal = crash(severity: .fatal)
        let minor = crash(severity: .propertyDamage)
        let fatalRoute = await service(records: [fatal]).analyze(route(), departure: .daytime, mode: .driving)
        let minorRoute = await service(records: [minor]).analyze(route(), departure: .daytime, mode: .driving)
        XCTAssertGreaterThan(fatalRoute.exposure.score, minorRoute.exposure.score)
    }

    func testNighttimeHistoryIncreasesExposureAtNight() async {
        let record = crash(severity: .injury, lighting: .darkLit)
        let scorer = service(records: [record])
        let day = await scorer.analyze(route(), departure: .daytime, mode: .driving)
        let night = await scorer.analyze(route(), departure: .nighttime, mode: .driving)
        XCTAssertGreaterThan(night.exposure.score, day.exposure.score)
        XCTAssertGreaterThan(night.exposure.nighttimeAdjustmentMiles, 0)
    }

    func testNoNearbyCrashProducesLowerExposure() async {
        let distant = CrashRecord(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: 41, longitude: -74), timestamp: Date(), severity: .fatal, fatal: true, injury: true, pedestrianInvolved: false, cyclistInvolved: false, roadName: "Elsewhere", intersectionName: nil, lightingCondition: .darkUnlit, weatherCondition: .clear, speedLimit: 60, roadClass: .highway)
        let analyzed = await service(records: [distant]).analyze(route(), departure: .daytime, mode: .driving)
        XCTAssertEqual(analyzed.exposure.score, 0)
        XCTAssertEqual(analyzed.exposure.level, .lower)
    }

    func testSegmentExposureAggregatesOverRouteDistance() async {
        let analyzed = await service(records: [crash(severity: .seriousInjury)]).analyze(route(), departure: .daytime, mode: .driving)
        XCTAssertEqual(analyzed.exposure.segments.count, 1)
        XCTAssertGreaterThan(analyzed.exposure.score, 0)
        XCTAssertGreaterThan(analyzed.exposure.severeCrashExposure, 0)
    }

    func testRouteRankingRespondsToPreference() async {
        let routes = await [route(minutes: 18, kind: .fastest), route(minutes: 22, kind: .lowerExposure)].asyncMap { await service(records: []).analyze($0, departure: .daytime, mode: .driving) }
        var first = routes[0]
        var second = routes[1]
        first.exposure = RouteExposure(score: 4, level: .elevated, severeCrashExposure: 2, intersectionCount: 4, elevatedMiles: 2, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: [])
        second.exposure = RouteExposure(score: 0.2, level: .lower, severeCrashExposure: 0, intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: [])
        let scorer = service(records: [])
        XCTAssertEqual(scorer.rank([first, second], preference: 0).first?.route.kind, .fastest)
        XCTAssertEqual(scorer.rank([first, second], preference: 1).first?.route.kind, .lowerExposure)
    }

    private func service(records: [CrashRecord]) -> RiskScoringService { RiskScoringService(provider: TestProvider(records: records)) }

    private func route(minutes: Int = 18, kind: RouteKind = .fastest) -> NavigationRoute {
        NavigationRoute(id: UUID(), kind: kind, name: "Test Road", expectedTravelTime: Double(minutes * 60), distanceMeters: routeSegment.distanceMeters, segments: [routeSegment], exposure: RouteExposure(score: 0, level: .lower, severeCrashExposure: 0, intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: []), isSampleData: true)
    }

    private func crash(severity: CrashSeverity, lighting: LightingCondition = .daylight) -> CrashRecord {
        CrashRecord(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: 40.005, longitude: -74.0), timestamp: Date(), severity: severity, fatal: severity == .fatal, injury: severity >= .injury, pedestrianInvolved: false, cyclistInvolved: false, roadName: "Test Road", intersectionName: "Test & Road", lightingCondition: lighting, weatherCondition: .clear, speedLimit: 45, roadClass: .arterial)
    }
}

private struct TestProvider: CrashDataProvider {
    let records: [CrashRecord]
    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord] { records.filter { Geographic.pointToSegmentDistance(point: $0.coordinate, start: segment.start, end: segment.end) <= radius } }
    func allCrashes() async -> [CrashRecord] { records }
}
