import CoreLocation
import Foundation

struct RoutePosition {
    let distanceFromRoute: CLLocationDistance
    let distanceAlongRoute: CLLocationDistance
    let routeLength: CLLocationDistance

    var progress: Double { routeLength > 0 ? min(1, max(0, distanceAlongRoute / routeLength)) : 0 }
}

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

    static func coordinate(on segments: [GeographicSegment], progress: Double) -> CLLocationCoordinate2D? {
        guard let first = segments.first else { return nil }
        let routeLength = segments.reduce(0) { $0 + $1.distanceMeters }
        var remaining = routeLength * min(1, max(0, progress))
        for segment in segments {
            let length = segment.distanceMeters
            if remaining <= length {
                let fraction = length > 0 ? remaining / length : 0
                return CLLocationCoordinate2D(
                    latitude: segment.start.latitude + (segment.end.latitude - segment.start.latitude) * fraction,
                    longitude: segment.start.longitude + (segment.end.longitude - segment.start.longitude) * fraction
                )
            }
            remaining -= length
        }
        return segments.last?.end ?? first.end
    }

    static func heading(on segments: [GeographicSegment], progress: Double) -> Double? {
        guard !segments.isEmpty else { return nil }
        let routeLength = segments.reduce(0) { $0 + $1.distanceMeters }
        var remaining = routeLength * min(1, max(0, progress))
        for segment in segments {
            if remaining <= segment.distanceMeters {
                let east = (segment.end.longitude - segment.start.longitude) * cos(segment.start.latitude * .pi / 180)
                let north = segment.end.latitude - segment.start.latitude
                return atan2(east, north)
            }
            remaining -= segment.distanceMeters
        }
        guard let last = segments.last else { return nil }
        let east = (last.end.longitude - last.start.longitude) * cos(last.start.latitude * .pi / 180)
        return atan2(east, last.end.latitude - last.start.latitude)
    }

    static func position(on segments: [GeographicSegment], near point: CLLocationCoordinate2D) -> RoutePosition? {
        guard !segments.isEmpty else { return nil }
        let routeLength = segments.reduce(0) { $0 + $1.distanceMeters }
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        var bestProgress: CLLocationDistance = 0
        var distanceBeforeSegment: CLLocationDistance = 0

        for segment in segments {
            let latitudeScale = 111_132.0
            let longitudeScale = 111_320.0 * cos(segment.start.latitude * .pi / 180)
            let px = (point.longitude - segment.start.longitude) * longitudeScale
            let py = (point.latitude - segment.start.latitude) * latitudeScale
            let ex = (segment.end.longitude - segment.start.longitude) * longitudeScale
            let ey = (segment.end.latitude - segment.start.latitude) * latitudeScale
            let lengthSquared = ex * ex + ey * ey
            let fraction = lengthSquared > 0 ? min(1, max(0, (px * ex + py * ey) / lengthSquared)) : 0
            let distance = hypot(px - fraction * ex, py - fraction * ey)
            if distance < bestDistance {
                bestDistance = distance
                bestProgress = distanceBeforeSegment + segment.distanceMeters * fraction
            }
            distanceBeforeSegment += segment.distanceMeters
        }

        return RoutePosition(distanceFromRoute: bestDistance, distanceAlongRoute: bestProgress, routeLength: routeLength)
    }
}
