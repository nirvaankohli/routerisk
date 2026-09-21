import CoreLocation
import MapKit

protocol RoutingService {
    func routes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: TravelMode) async throws -> [NavigationRoute]
}

struct MapRoutingService: RoutingService {
    func routes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: TravelMode) async throws -> [NavigationRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mode == .driving ? .automobile : mode == .cycling ? .cycling : .walking
        let response = try await MKDirections(request: request).calculate()
        let kinds: [RouteKind] = [.fastest, .balanced, .lowerExposure]
        return response.routes.prefix(3).enumerated().map { index, mapRoute in
            let points = mapRoute.polyline.points()
            let sampleInterval = max(1, mapRoute.polyline.pointCount / 70)
            var coordinates = stride(from: 0, to: mapRoute.polyline.pointCount, by: sampleInterval).map { points[$0].coordinate }
            let final = points[mapRoute.polyline.pointCount - 1].coordinate
            if coordinates.last?.latitude != final.latitude || coordinates.last?.longitude != final.longitude { coordinates.append(final) }
            let segments = Geographic.segments(from: coordinates, roadName: mapRoute.name.isEmpty ? "Route segment" : mapRoute.name)
            return NavigationRoute(id: UUID(), kind: kinds[min(index, kinds.count - 1)], name: mapRoute.name.isEmpty ? "Suggested route" : mapRoute.name,
                expectedTravelTime: mapRoute.expectedTravelTime, distanceMeters: mapRoute.distance, segments: segments,
                exposure: RouteExposure(score: 0, level: .moderate, severeCrashExposure: 0, intersectionCount: 0, elevatedMiles: 0, nighttimeAdjustmentMiles: 0, pedestrianExposure: 0, cyclistExposure: 0, segments: []), isSampleData: false)
        }
    }
}
