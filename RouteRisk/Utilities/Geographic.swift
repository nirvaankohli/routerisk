import CoreLocation
import Foundation

enum Geographic {
    static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    static func pointToSegmentDistance(point: CLLocationCoordinate2D, start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> CLLocationDistance {
        let origin = CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)
        let metersPerLatitude = 111_132.0
        let metersPerLongitude = 111_320.0 * cos(origin.latitude * .pi / 180)
        let px = (point.longitude - origin.longitude) * metersPerLongitude
        let py = (point.latitude - origin.latitude) * metersPerLatitude
        let ex = (end.longitude - origin.longitude) * metersPerLongitude
        let ey = (end.latitude - origin.latitude) * metersPerLatitude
        let lengthSquared = ex * ex + ey * ey
        guard lengthSquared > 0 else { return hypot(px, py) }
        let t = max(0, min(1, (px * ex + py * ey) / lengthSquared))
        return hypot(px - t * ex, py - t * ey)
    }

    static func segments(from coordinates: [CLLocationCoordinate2D], roadName: String) -> [GeographicSegment] {
        zip(coordinates, coordinates.dropFirst()).map { GeographicSegment(start: $0.0, end: $0.1, roadName: roadName) }
    }
}
