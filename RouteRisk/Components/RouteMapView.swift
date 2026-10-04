import MapKit
import SwiftUI

struct RouteMapView: UIViewRepresentable {
    let routes: [NavigationRoute]
    let selectedRoute: NavigationRoute?
    let showsUserLocation: Bool
    let usesSatelliteMap: Bool
    let centerCoordinate: CLLocationCoordinate2D?
    let recenterToken: UUID
    let destination: CLLocationCoordinate2D
    let destinationName: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = usesSatelliteMap ? .hybrid : .mutedStandard
        map.showsUserLocation = showsUserLocation
        map.showsCompass = false
        map.pointOfInterestFilter = .includingAll
        let region = MKCoordinateRegion(center: DemoRoutes.origin, latitudinalMeters: 28_000, longitudinalMeters: 28_000)
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.showsUserLocation = showsUserLocation
        map.mapType = usesSatelliteMap ? .hybrid : .mutedStandard
        if context.coordinator.lastRecenterToken != recenterToken {
            context.coordinator.lastRecenterToken = recenterToken
            let coordinate = centerCoordinate ?? DemoRoutes.origin
            map.setCenter(coordinate, animated: true)
        }
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        context.coordinator.styles.removeAll()

        let destinationPin = MKPointAnnotation()
        destinationPin.coordinate = destination
        destinationPin.title = destinationName
        destinationPin.subtitle = "Destination"
        map.addAnnotation(destinationPin)

        for route in routes where route.id != selectedRoute?.id {
            let coordinates = route.segments.flatMap { [$0.start, $0.end] }
            let overlay = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.styles[ObjectIdentifier(overlay)] = .candidate
            map.addOverlay(overlay)
        }
        guard let selectedRoute else { return }
        for item in selectedRoute.exposure.segments {
            let coordinates = [item.segment.start, item.segment.end]
            let overlay = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.styles[ObjectIdentifier(overlay)] = .exposure(item.level)
            map.addOverlay(overlay)
            if item.level >= .elevated, item.crashCount > 0 {
                let pin = MKPointAnnotation()
                pin.coordinate = item.segment.start
                pin.title = item.segment.roadName
                pin.subtitle = "Historical exposure: \(item.level.title). \(item.crashCount) crashes in demo data."
                map.addAnnotation(pin)
            }
        }

        let routeSignature = routes.map(\.id)
        if context.coordinator.lastRouteSignature != routeSignature {
            context.coordinator.lastRouteSignature = routeSignature
            let allCoordinates = routes.flatMap { $0.segments.flatMap { [$0.start, $0.end] } }
            if let first = allCoordinates.first {
                let routeRect = allCoordinates.dropFirst().map(MKMapPoint.init).reduce(MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))) { partial, point in
                    partial.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                }
                map.setVisibleMapRect(routeRect, edgePadding: UIEdgeInsets(top: 170, left: 38, bottom: 360, right: 38), animated: true)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        enum Style { case candidate, exposure(ExposureLevel) }
        var styles: [ObjectIdentifier: Style] = [:]
        var lastRecenterToken: UUID?
        var lastRouteSignature: [UUID] = []

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "RouteRiskMarker"
            let marker = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            marker.annotation = annotation
            marker.canShowCallout = true
            let isDestination = annotation.subtitle == "Destination"
            marker.markerTintColor = isDestination ? .systemRed : .systemOrange
            marker.glyphImage = UIImage(systemName: isDestination ? "flag.fill" : "exclamationmark.triangle.fill")
            return marker
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            switch styles[ObjectIdentifier(line)] {
            case .candidate:
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.25)
                renderer.lineWidth = 4
            case let .exposure(level):
                renderer.strokeColor = UIColor(level.color)
                renderer.lineWidth = 7
            case .none:
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 5
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}
