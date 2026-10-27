import MapKit
import SwiftUI

struct RouteMapView: UIViewRepresentable {
    let routes: [NavigationRoute]
    let selectedRoute: NavigationRoute?
    let showsExposure: Bool
    let showsDestination: Bool
    let showsUserLocation: Bool
    let isNavigating: Bool
    let followsUser: Bool
    let usesSatelliteMap: Bool
    let centerCoordinate: CLLocationCoordinate2D?
    let reportedIncidents: [LiveRoadIncident]
    let animatedLocation: CLLocationCoordinate2D?
    let animatedHeading: Double?
    let practiceCrashCoordinate: CLLocationCoordinate2D?
    let recenterToken: UUID
    let destination: CLLocationCoordinate2D
    let destinationName: String
    let stop: TripStop?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        configureMap(map)
        map.showsUserLocation = showsUserLocation
        map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: isNavigating ? 185 : 0, right: 0)
        context.coordinator.selectedRoute = isNavigating ? selectedRoute : nil
        map.showsCompass = false
        let region = MKCoordinateRegion(center: centerCoordinate ?? destination, latitudinalMeters: 28_000, longitudinalMeters: 28_000)
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.selectedRoute = isNavigating ? selectedRoute : nil
        map.showsUserLocation = showsUserLocation
        map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: isNavigating ? 185 : 0, right: 0)
        if context.coordinator.lastSatelliteSetting != usesSatelliteMap {
            configureMap(map)
            context.coordinator.lastSatelliteSetting = usesSatelliteMap
        }
        if context.coordinator.wasFollowingUser != followsUser {
            context.coordinator.wasFollowingUser = followsUser
            if followsUser, let centerCoordinate {
                map.setRegion(MKCoordinateRegion(center: centerCoordinate, latitudinalMeters: 1_800, longitudinalMeters: 1_800), animated: true)
                map.setUserTrackingMode(animatedLocation == nil ? .follow : .none, animated: animatedLocation == nil)
            } else {
                map.setUserTrackingMode(.none, animated: false)
                context.coordinator.lastRouteSignature = []
            }
        }
        if context.coordinator.lastRecenterToken != recenterToken {
            context.coordinator.lastRecenterToken = recenterToken
            if followsUser {
                if animatedLocation != nil, let centerCoordinate {
                    map.setRegion(MKCoordinateRegion(center: centerCoordinate, latitudinalMeters: 1_800, longitudinalMeters: 1_800), animated: true)
                } else {
                    map.setUserTrackingMode(.follow, animated: true)
                }
            } else if let centerCoordinate {
                map.setCenter(centerCoordinate, animated: true)
            }
        }
        context.coordinator.updateUserHeading(on: map)
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) && !($0 is ShowcaseLocationAnnotation) })
        context.coordinator.styles.removeAll()

        if let animatedLocation {
            let marker: ShowcaseLocationAnnotation
            if let existing = context.coordinator.showcaseMarker {
                marker = existing
            } else {
                marker = ShowcaseLocationAnnotation()
                context.coordinator.showcaseMarker = marker
                map.addAnnotation(marker)
            }
            marker.heading = animatedHeading.map { CGFloat($0) } ?? context.coordinator.routeHeading(at: animatedLocation) ?? 0
            marker.coordinate = animatedLocation
            map.view(for: marker)?.transform = CGAffineTransform(rotationAngle: marker.heading)
            if followsUser {
                map.setRegion(MKCoordinateRegion(center: animatedLocation, latitudinalMeters: 1_800, longitudinalMeters: 1_800), animated: true)
            }
        } else if let marker = context.coordinator.showcaseMarker {
            map.removeAnnotation(marker)
            context.coordinator.showcaseMarker = nil
        }

        if showsDestination {
            let destinationPin = MKPointAnnotation()
            destinationPin.coordinate = destination
            destinationPin.title = destinationName
            destinationPin.subtitle = "Destination"
            map.addAnnotation(destinationPin)
        }
        if let stop {
            let stopPin = MKPointAnnotation()
            stopPin.coordinate = stop.coordinate
            stopPin.title = stop.name
            stopPin.subtitle = "Stop"
            map.addAnnotation(stopPin)
        }
        for incident in reportedIncidents {
            let crashPin = CrashReportAnnotation()
            crashPin.coordinate = incident.coordinate
            crashPin.title = incident.title
            crashPin.subtitle = "511NJ active incident"
            map.addAnnotation(crashPin)
        }
        if let practiceCrashCoordinate {
            let crashPin = CrashReportAnnotation()
            crashPin.coordinate = practiceCrashCoordinate
            crashPin.title = "Practice crash report"
            crashPin.subtitle = "Guided showcase"
            map.addAnnotation(crashPin)
        }

        for route in routes where route.id != selectedRoute?.id {
            let coordinates = route.segments.flatMap { [$0.start, $0.end] }
            let overlay = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.styles[ObjectIdentifier(overlay)] = .candidate
            map.addOverlay(overlay)
        }
        guard let selectedRoute else { return }
        let selectedCoordinates = selectedRoute.segments.flatMap { [$0.start, $0.end] }
        let selectedLine = MKPolyline(coordinates: selectedCoordinates, count: selectedCoordinates.count)
        context.coordinator.styles[ObjectIdentifier(selectedLine)] = .route
        map.addOverlay(selectedLine)

        for item in selectedRoute.exposure.segments {
            guard showsExposure, item.level >= .elevated else { continue }
            let coordinates = [item.segment.start, item.segment.end]
            let overlay = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.styles[ObjectIdentifier(overlay)] = .exposure(item.level)
            map.addOverlay(overlay)
        }

        let routeSignature = routes.map(\.id)
        if context.coordinator.lastRouteSignature != routeSignature {
            context.coordinator.lastRouteSignature = routeSignature
            if !followsUser {
                let allCoordinates = routes.flatMap { $0.segments.flatMap { [$0.start, $0.end] } }
                if let first = allCoordinates.first {
                    let routeRect = allCoordinates.dropFirst().map(MKMapPoint.init).reduce(MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))) { partial, point in
                        partial.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                    }
                    map.setVisibleMapRect(routeRect, edgePadding: UIEdgeInsets(top: 170, left: 38, bottom: 250, right: 38), animated: true)
                }
            }
        }
    }

    private func configureMap(_ map: MKMapView) {
        if usesSatelliteMap {
            let configuration = MKHybridMapConfiguration()
            configuration.showsTraffic = true
            map.preferredConfiguration = configuration
        } else {
            let configuration = MKStandardMapConfiguration()
            configuration.emphasisStyle = .muted
            configuration.showsTraffic = true
            map.preferredConfiguration = configuration
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        enum Style { case candidate, route, exposure(ExposureLevel) }
        var styles: [ObjectIdentifier: Style] = [:]
        var lastRecenterToken: UUID?
        var lastRouteSignature: [UUID] = []
        var wasFollowingUser = false
        var lastSatelliteSetting: Bool?
        var selectedRoute: NavigationRoute?
        fileprivate var showcaseMarker: ShowcaseLocationAnnotation?

        private static let navigationImage: UIImage = {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48), format: format)
            return renderer.image { _ in
                UIColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0).setFill()
                UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 44, height: 44)).fill()

                let arrow = UIBezierPath()
                arrow.move(to: CGPoint(x: 24, y: 10))
                arrow.addCurve(to: CGPoint(x: 27.2, y: 12.4), controlPoint1: CGPoint(x: 25.5, y: 10), controlPoint2: CGPoint(x: 26.6, y: 10.8))
                arrow.addLine(to: CGPoint(x: 35, y: 34.8))
                arrow.addQuadCurve(to: CGPoint(x: 31.2, y: 38.6), controlPoint: CGPoint(x: 36.4, y: 38.9))
                arrow.addQuadCurve(to: CGPoint(x: 29.8, y: 37.8), controlPoint: CGPoint(x: 30.4, y: 38.5))
                arrow.addLine(to: CGPoint(x: 24, y: 32))
                arrow.addLine(to: CGPoint(x: 18.2, y: 37.8))
                arrow.addQuadCurve(to: CGPoint(x: 16.8, y: 38.6), controlPoint: CGPoint(x: 17.6, y: 38.5))
                arrow.addQuadCurve(to: CGPoint(x: 13, y: 34.8), controlPoint: CGPoint(x: 11.6, y: 38.9))
                arrow.addLine(to: CGPoint(x: 20.8, y: 12.4))
                arrow.addCurve(to: CGPoint(x: 24, y: 10), controlPoint1: CGPoint(x: 21.4, y: 10.8), controlPoint2: CGPoint(x: 22.5, y: 10))
                arrow.close()
                UIColor.white.setFill()
                arrow.fill()
            }
        }()

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let position = annotation as? MKUserLocation {
                let identifier = "RouteRiskNavigationArrow"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = position
                view.image = Self.navigationImage
                view.backgroundColor = .clear
                view.isOpaque = false
                view.canShowCallout = false
                view.displayPriority = .required
                view.isAccessibilityElement = true
                view.accessibilityLabel = "Current location"
                return view
            }
            if let position = annotation as? ShowcaseLocationAnnotation {
                let identifier = "RouteRiskShowcaseArrow"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = position
                view.image = Self.navigationImage
                view.backgroundColor = .clear
                view.isOpaque = false
                view.canShowCallout = false
                view.displayPriority = .required
                view.transform = CGAffineTransform(rotationAngle: position.heading)
                view.isAccessibilityElement = true
                view.accessibilityLabel = "Guided showcase position"
                return view
            }
            let identifier = "RouteRiskMarker"
            let marker = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            marker.annotation = annotation
            marker.canShowCallout = true
            let isDestination = annotation.subtitle == "Destination"
            let isStop = annotation.subtitle == "Stop"
            let isCrash = annotation is CrashReportAnnotation
            marker.markerTintColor = isDestination ? .systemRed : isStop ? .systemBlue : .systemOrange
            marker.glyphImage = UIImage(systemName: isDestination ? "flag.fill" : isStop ? "mappin" : isCrash ? "exclamationmark.triangle.fill" : "circle.fill")
            marker.glyphTintColor = .white
            if isCrash { marker.displayPriority = .required }
            return marker
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            updateUserHeading(on: mapView)
        }

        func updateUserHeading(on mapView: MKMapView) {
            guard let location = mapView.userLocation.location,
                  let view = mapView.view(for: mapView.userLocation) else { return }
            if location.speed >= 1, location.course >= 0 {
                view.transform = CGAffineTransform(rotationAngle: CGFloat(location.course * .pi / 180))
            } else if let segment = selectedRoute?.segments.min(by: {
                Geographic.pointToSegmentDistance(point: location.coordinate, start: $0.start, end: $0.end)
                    < Geographic.pointToSegmentDistance(point: location.coordinate, start: $1.start, end: $1.end)
            }), Geographic.pointToSegmentDistance(point: location.coordinate, start: segment.start, end: segment.end) < 100 {
                let east = (segment.end.longitude - segment.start.longitude) * cos(location.coordinate.latitude * .pi / 180)
                let north = segment.end.latitude - segment.start.latitude
                view.transform = CGAffineTransform(rotationAngle: CGFloat(atan2(east, north)))
            } else {
                view.transform = .identity
            }
        }

        func routeHeading(at coordinate: CLLocationCoordinate2D) -> CGFloat? {
            guard let segment = selectedRoute?.segments.min(by: {
                Geographic.pointToSegmentDistance(point: coordinate, start: $0.start, end: $0.end)
                    < Geographic.pointToSegmentDistance(point: coordinate, start: $1.start, end: $1.end)
            }) else { return nil }
            let east = (segment.end.longitude - segment.start.longitude) * cos(coordinate.latitude * .pi / 180)
            let north = segment.end.latitude - segment.start.latitude
            return CGFloat(atan2(east, north))
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            switch styles[ObjectIdentifier(line)] {
            case .candidate:
                renderer.strokeColor = UIColor(red: 0.67, green: 0.76, blue: 1.0, alpha: 0.88)
                renderer.lineWidth = 5
            case .route:
                renderer.strokeColor = UIColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0)
                renderer.lineWidth = 7
            case let .exposure(level):
                renderer.strokeColor = UIColor(level.color)
                renderer.lineWidth = 4
            case .none:
                renderer.strokeColor = UIColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0)
                renderer.lineWidth = 5
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

private final class CrashReportAnnotation: MKPointAnnotation {}
private final class ShowcaseLocationAnnotation: MKPointAnnotation {
    var heading: CGFloat = 0
}
