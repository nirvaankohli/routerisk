import CoreLocation
import Foundation

protocol CrashDataProvider {
    func refreshData(for routes: [NavigationRoute]) async -> CrashDataStatus
    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord]
    func allCrashes() async -> [CrashRecord]
}

extension CrashDataProvider {
    func refreshData(for routes: [NavigationRoute]) async -> CrashDataStatus {
        .unavailable("No historical crash source is configured for this route.")
    }
}

enum CrashDataStatus: Equatable {
    case live
    case demo
    case unavailable(String)

    var badgeTitle: String {
        switch self {
        case .live: return "Historical data"
        case .demo: return "Demo data"
        case .unavailable: return "Coverage unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .live: return "checkmark.shield.fill"
        case .demo: return "testtube.2"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    var detail: String {
        switch self {
        case .live:
            return "DVRPC historical New Jersey fatal and serious-injury crash data (2017–2021)."
        case .demo:
            return "Illustrative sample crash records for the offline demo."
        case let .unavailable(message):
            return message
        }
    }
}

struct SampleCrashDataProvider: CrashDataProvider {
    let records: [CrashRecord] = SampleCrashRecords.records

    func refreshData(for routes: [NavigationRoute]) async -> CrashDataStatus { .demo }

    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord] {
        records.filter { Geographic.pointToSegmentDistance(point: $0.coordinate, start: segment.start, end: segment.end) <= radius }
    }

    func allCrashes() async -> [CrashRecord] { records }
}

/// Reads the DVRPC public high-injury crash layer. The dataset covers the greater
/// Philadelphia region, including Mercer County, New Jersey, and needs no API key.
actor DVRPCCrashDataProvider: CrashDataProvider {
    private static let queryURL = URL(string: "https://arcgis.dvrpc.org/portal/rest/services/hosted/hin_webmap_data/FeatureServer/1/query")!
    private static let coverage = (minLatitude: 39.45, maxLatitude: 40.85, minLongitude: -76.25, maxLongitude: -74.00)

    private var records: [CrashRecord] = []

    func refreshData(for routes: [NavigationRoute]) async -> CrashDataStatus {
        let coordinates = routes.flatMap { $0.segments.flatMap { [$0.start, $0.end] } }
        guard !coordinates.isEmpty else {
            records = []
            return .unavailable("No route geometry is available to check historical crash coverage.")
        }
        guard overlapsCoverage(coordinates) else {
            records = []
            return .unavailable("Historical crash coverage is currently available only in the greater Philadelphia region.")
        }

        do {
            records = try await fetchRecords(around: coordinates)
            return .live
        } catch {
            records = []
            return .unavailable("The public historical crash source is temporarily unavailable. Route timing is still live.")
        }
    }

    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord] {
        records.filter { Geographic.pointToSegmentDistance(point: $0.coordinate, start: segment.start, end: segment.end) <= radius }
    }

    func allCrashes() async -> [CrashRecord] { records }

    private func overlapsCoverage(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        let coverage = Self.coverage
        return coordinates.contains {
            $0.latitude >= coverage.minLatitude && $0.latitude <= coverage.maxLatitude &&
            $0.longitude >= coverage.minLongitude && $0.longitude <= coverage.maxLongitude
        }
    }

    private func fetchRecords(around coordinates: [CLLocationCoordinate2D]) async throws -> [CrashRecord] {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        // A small buffer keeps nearby intersections included without requesting the full regional layer.
        let envelope = "\((longitudes.min() ?? 0) - 0.02),\((latitudes.min() ?? 0) - 0.02),\((longitudes.max() ?? 0) + 0.02),\((latitudes.max() ?? 0) + 0.02)"
        var components = URLComponents(url: Self.queryURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: envelope),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "casenumber,totalkilled,major_injury,injury,pedestrian,bicycle,intersection,county,municipality,route,crash_location"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "resultRecordCount", value: "2000"),
            URLQueryItem(name: "f", value: "geojson")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(DVRPCFeatureCollection.self, from: data).features.compactMap(CrashRecord.init)
    }
}

private struct DVRPCFeatureCollection: Decodable {
    let features: [DVRPCFeature]
}

private struct DVRPCFeature: Decodable {
    struct Geometry: Decodable { let coordinates: [Double] }
    struct Properties: Decodable {
        let casenumber: String?
        let totalkilled: Double?
        let major_injury: Double?
        let injury: String?
        let pedestrian: String?
        let bicycle: String?
        let intersection: String?
        let county: String?
        let municipality: String?
        let route: String?
        let crash_location: String?
    }

    let geometry: Geometry
    let properties: Properties
}

private extension CrashRecord {
    init?(feature: DVRPCFeature) {
        guard feature.geometry.coordinates.count >= 2 else { return nil }
        let properties = feature.properties
        let fatal = (properties.totalkilled ?? 0) > 0
        let serious = (properties.major_injury ?? 0) > 0
        let injury = properties.injury?.lowercased() == "true"
        let severity: CrashSeverity = fatal ? .fatal : serious ? .seriousInjury : injury ? .injury : .seriousInjury
        let roadName = properties.crash_location ?? properties.route ?? properties.municipality ?? properties.county ?? "Reported crash location"
        let year = Int(properties.casenumber?.prefix(4) ?? "") ?? 2021
        let timestamp = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 7, day: 1)) ?? .distantPast
        self.init(
            id: UUID(), coordinate: CLLocationCoordinate2D(latitude: feature.geometry.coordinates[1], longitude: feature.geometry.coordinates[0]),
            timestamp: timestamp, severity: severity, fatal: fatal, injury: injury || serious || fatal,
            pedestrianInvolved: properties.pedestrian?.lowercased() == "true", cyclistInvolved: properties.bicycle?.lowercased() == "true",
            roadName: roadName, intersectionName: properties.intersection?.lowercased() == "true" ? roadName : nil,
            lightingCondition: .daylight, weatherCondition: .clear,
            speedLimit: 0,
            roadClass: roadName.contains("US ") || roadName.contains("ROUTE") ? .arterial : .local
        )
    }
}
