import CoreLocation
import XCTest
@testable import RouteRisk

final class RiskScoringServiceTests: XCTestCase {
    private let routeSegment = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0), end: CLLocationCoordinate2D(latitude: 40.01, longitude: -74.0), roadName: "Test Road")

    func testPointToRoadDistanceIsSmallForNearbyPoint() {
        let distance = Geographic.pointToSegmentDistance(point: CLLocationCoordinate2D(latitude: 40.005, longitude: -73.999), start: routeSegment.start, end: routeSegment.end)
        XCTAssertLessThan(distance, 100)
    }

    func testRoutePositionTracksProgressAndDistanceFromPath() {
        let onRoute = Geographic.position(on: [routeSegment], near: CLLocationCoordinate2D(latitude: 40.005, longitude: -74.0))
        XCTAssertNotNil(onRoute)
        XCTAssertEqual(onRoute?.progress ?? 0, 0.5, accuracy: 0.01)
        XCTAssertLessThan(onRoute?.distanceFromRoute ?? .infinity, 1)

        let away = Geographic.position(on: [routeSegment], near: CLLocationCoordinate2D(latitude: 40.005, longitude: -73.99))
        XCTAssertGreaterThan(away?.distanceFromRoute ?? 0, 180)
    }

    func testDemoDriverInterpolatesAlongRoute() {
        let start = Geographic.coordinate(on: [routeSegment], progress: 0)
        let halfway = Geographic.coordinate(on: [routeSegment], progress: 0.5)
        let end = Geographic.coordinate(on: [routeSegment], progress: 1)
        XCTAssertEqual(start?.latitude ?? 0, 40, accuracy: 0.0001)
        XCTAssertEqual(halfway?.latitude ?? 0, 40.005, accuracy: 0.0001)
        XCTAssertEqual(end?.latitude ?? 0, 40.01, accuracy: 0.0001)
    }

    func testShowcaseMovesAtPlausibleRoadSpeed() {
        let route = DemoRoutes.routes()[0]
        let speed = ShowcaseMotion.metersPerSecond(for: route)
        let progress = ShowcaseMotion.nextProgress(on: route.segments, from: 0.5, speed: speed, seconds: 0.5)
        let routeLength = route.segments.reduce(0) { $0 + $1.distanceMeters }
        XCTAssertGreaterThan(speed, 6)
        XCTAssertLessThanOrEqual(speed, 20.1)
        XCTAssertEqual((progress - 0.5) * routeLength, speed * 0.5, accuracy: 0.1)
        XCTAssertLessThan(progress - 0.5, 0.001)
    }

    func testShowcaseArrowFollowsRoadDirection() {
        let east = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40, longitude: -74),
                                     end: CLLocationCoordinate2D(latitude: 40, longitude: -73.99), roadName: "East")
        let north = GeographicSegment(start: east.end,
                                      end: CLLocationCoordinate2D(latitude: 40.01, longitude: -73.99), roadName: "North")
        XCTAssertEqual(Geographic.heading(on: [east, north], progress: 0.25) ?? 0, .pi / 2, accuracy: 0.01)
        XCTAssertEqual(Geographic.heading(on: [east, north], progress: 0.9) ?? 1, 0, accuracy: 0.01)
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
        NavigationRoute(id: UUID(), kind: kind, name: "Test Road", expectedTravelTime: Double(minutes * 60), distanceMeters: routeSegment.distanceMeters, segments: [routeSegment], instructions: [], exposure: RouteExposure(score: 0, level: .lower, severeCrashExposure: 0, intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: []), isSampleData: true)
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

final class TripSafetyTests: XCTestCase {
    func testParentPhoneValidation() {
        XCTAssertEqual(ParentContact.phoneNumber(from: "(555) 111-2222"), "5551112222")
        XCTAssertEqual(ParentContact.phoneNumber(from: "+1 555 111 2222"), "+15551112222")
        XCTAssertNil(ParentContact.phoneNumber(from: "555-1234"))
    }

    func testImpactRequiresDrivingJoltAndSuddenStop() {
        var detector = ImpactHeuristic()
        detector.observeImpact(4, at: 1)
        XCTAssertFalse(detector.observeSpeed(0, at: 2))
        XCTAssertFalse(detector.observeSpeed(12, at: 3))
        detector.observeImpact(2, at: 4)
        XCTAssertFalse(detector.observeSpeed(0, at: 5))
        XCTAssertFalse(detector.observeSpeed(12, at: 6))
        detector.observeImpact(4, at: 7)
        XCTAssertTrue(detector.observeSpeed(0, at: 9))
    }

    func testStaleImpactDoesNotTrigger() {
        var detector = ImpactHeuristic()
        XCTAssertFalse(detector.observeSpeed(12, at: 1))
        detector.observeImpact(4, at: 2)
        XCTAssertFalse(detector.observeSpeed(0, at: 11))
    }
}

final class LiveIncidentTests: XCTestCase {
    func testNJ511FeedKeepsCrashReportsWithCoordinates() throws {
        let xml = """
        <rss xmlns:georss="http://www.georss.org/georss"><channel>
          <item><title>US 1 northbound : Crash</title><pubDate>Sun, 25 Oct 2026 00:26:09 -0400</pubDate><georss:point>40.05 -74.0</georss:point></item>
          <item><title>US 1 northbound : Disabled vehicle</title><georss:point>40.06 -74.0</georss:point></item>
          <item><title>NJ 27 : Crash</title><georss:point>not a location</georss:point></item>
        </channel></rss>
        """
        let incidents = try NJ511IncidentParser.parse(Data(xml.utf8))
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents[0].title, "US 1 northbound : Crash")
        XCTAssertEqual(incidents[0].coordinate.latitude, 40.05, accuracy: 0.0001)
        XCTAssertNotNil(incidents[0].reportedAt)
    }

    func testRouteAlertRequiresCrashAheadNearSelectedRoute() {
        let segment = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40.0, longitude: -74),
                                        end: CLLocationCoordinate2D(latitude: 40.1, longitude: -74), roadName: "Test Road")
        let route = NavigationRoute(id: UUID(), kind: .fastest, name: "Test Road", expectedTravelTime: 600,
                                    distanceMeters: segment.distanceMeters, segments: [segment], instructions: [],
                                    exposure: RouteExposure(score: 0, level: .lower, severeCrashExposure: 0, intersectionCount: 0,
                                                            elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0,
                                                            cyclistExposure: 0, segments: []), isSampleData: true)
        let incidents = [
            LiveRoadIncident(id: "ahead", title: "Crash", coordinate: CLLocationCoordinate2D(latitude: 40.05, longitude: -74), reportedAt: nil),
            LiveRoadIncident(id: "behind", title: "Crash", coordinate: CLLocationCoordinate2D(latitude: 40.01, longitude: -74), reportedAt: nil),
            LiveRoadIncident(id: "elsewhere", title: "Crash", coordinate: CLLocationCoordinate2D(latitude: 40.05, longitude: -73.98), reportedAt: nil)
        ]
        let alerts = RouteIncidentMatcher.ahead(incidents, on: route, from: CLLocationCoordinate2D(latitude: 40.02, longitude: -74))
        XCTAssertEqual(alerts.map(\.incident.id), ["ahead"])
        XCTAssertGreaterThan(alerts[0].metersAhead, 3_000)
    }

    func testIncidentRerouteOnlyAcceptsRoutesClearOfReportedCrash() {
        let incident = CLLocationCoordinate2D(latitude: 40.05, longitude: -74)
        let blocked = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40, longitude: -74),
                                        end: CLLocationCoordinate2D(latitude: 40.1, longitude: -74), roadName: "Blocked")
        let clear = GeographicSegment(start: CLLocationCoordinate2D(latitude: 40, longitude: -73.99),
                                      end: CLLocationCoordinate2D(latitude: 40.1, longitude: -73.99), roadName: "Clear")
        let exposure = RouteExposure(score: 0, level: .lower, severeCrashExposure: 0, intersectionCount: 0,
                                     elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0,
                                     cyclistExposure: 0, segments: [])
        let blockedRoute = NavigationRoute(id: UUID(), kind: .fastest, name: "Blocked", expectedTravelTime: 600,
                                           distanceMeters: blocked.distanceMeters, segments: [blocked], instructions: [],
                                           exposure: exposure, isSampleData: false)
        let clearRoute = NavigationRoute(id: UUID(), kind: .balanced, name: "Clear", expectedTravelTime: 700,
                                         distanceMeters: clear.distanceMeters, segments: [clear], instructions: [],
                                         exposure: exposure, isSampleData: false)
        XCTAssertFalse(RouteIncidentMatcher.avoids([incident], on: blockedRoute))
        XCTAssertTrue(RouteIncidentMatcher.avoids([incident], on: clearRoute))
    }

    func testGuidedDemoDetourClearsSimulatedCrash() {
        guard let fastest = DemoRoutes.routes().first,
              let position = Geographic.coordinate(on: fastest.segments, progress: 0.35) else {
            XCTFail("Demo route should have a position before the incident")
            return
        }
        XCTAssertFalse(RouteIncidentMatcher.avoids([DemoRoutes.incidentCoordinate], on: fastest))
        XCTAssertTrue(RouteIncidentMatcher.avoids([DemoRoutes.incidentCoordinate], on: DemoRoutes.incidentDetour(from: position)))
    }
}
