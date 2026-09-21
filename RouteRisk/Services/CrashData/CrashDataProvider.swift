import CoreLocation
import Foundation

protocol CrashDataProvider {
    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord]
    func allCrashes() async -> [CrashRecord]
}

/// Boundary for a future, privacy-conscious New Jersey crash-data backend.
protocol RemoteCrashDataProvider: CrashDataProvider {
    func refreshData(in region: CLLocationCoordinate2D) async throws
}

struct SampleCrashDataProvider: CrashDataProvider {
    let records: [CrashRecord] = SampleCrashRecords.records

    func crashes(near segment: GeographicSegment, radius: CLLocationDistance) async -> [CrashRecord] {
        records.filter { Geographic.pointToSegmentDistance(point: $0.coordinate, start: segment.start, end: segment.end) <= radius }
    }

    func allCrashes() async -> [CrashRecord] { records }
}
