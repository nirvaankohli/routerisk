import MapKit
import SwiftUI

struct RouteMapView: UIViewRepresentable {
    let routes: [NavigationRoute]
    let selectedRoute: NavigationRoute?
    let showsUserLocation: Bool
    let usesSatelliteMap: Bool
    let centerCoordinate: CLLocationCoordinate2D?
    let recenterToken: UUID

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
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        enum Style { case candidate, exposure(ExposureLevel) }
        var styles: [ObjectIdentifier: Style] = [:]
        var lastRecenterToken: UUID?

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
