import CoreLocation
import Foundation

@MainActor
final class NavigationViewModel: ObservableObject {
    @Published private(set) var routes: [NavigationRoute] = []
    @Published private(set) var rankedRoutes: [RankedRoute] = []
    @Published var selectedRouteID: UUID?
    @Published var riskPreference: Double = 0.5 { didSet { rerank(selectRecommended: true) } }
    @Published var departure: DeparturePeriod = .daytime { didSet { Task { await reanalyze() } } }
    @Published var mode: TravelMode = .driving { didSet { Task { await reanalyze() } } }
    @Published var destinationName = DemoRoutes.destinationName
    @Published private(set) var destinationCoordinate = DemoRoutes.destination
    @Published private(set) var originName = DemoRoutes.originName
    @Published private(set) var originCoordinate = DemoRoutes.origin
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var crashDataStatus: CrashDataStatus = .unavailable("Loading historical crash coverage…")

    private let liveScoring: RiskScoringService
    private var activeScoring: RiskScoringService
    private let routingService: any RoutingService
    private var origin = DemoRoutes.origin

    init(scoring: RiskScoringService = RiskScoringService(), routingService: any RoutingService = MapRoutingService()) {
        self.liveScoring = scoring
        self.activeScoring = scoring
        self.routingService = routingService
        Task { await loadDefaultRoute() }
    }

    var selectedRoute: NavigationRoute? { routes.first { $0.id == selectedRouteID } }

    func routeTo(destination: CLLocationCoordinate2D, name: String, origin: CLLocationCoordinate2D?, originName: String? = nil) async {
        isLoading = true
        errorMessage = nil
        activeScoring = liveScoring
        self.origin = origin ?? self.originCoordinate
        originCoordinate = self.origin
        self.originName = originName ?? (origin == nil ? "Your location" : self.originName)
        destinationName = name
        destinationCoordinate = destination
        do {
            let options = try await routingService.routes(from: self.origin, to: destination, mode: mode)
            guard !options.isEmpty else { throw RoutingError.noRoutes }
            await analyze(options)
        } catch {
            routes = []
            rankedRoutes = []
            selectedRouteID = nil
            crashDataStatus = .unavailable("Historical crash exposure is unavailable until a route loads.")
            errorMessage = "Couldn’t load routes. Check your connection and try again."
        }
        isLoading = false
    }

    func select(_ route: NavigationRoute) { selectedRouteID = route.id }

    func reroute(from location: CLLocationCoordinate2D, via stop: TripStop? = nil, avoiding incidents: [CLLocationCoordinate2D] = []) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let options: [NavigationRoute]
            if let stop {
                options = [try await routingService.route(from: location, via: stop.coordinate, to: destinationCoordinate, mode: mode)]
            } else {
                options = try await routingService.routes(from: location, to: destinationCoordinate, mode: mode)
            }
            guard !options.isEmpty else { throw RoutingError.noRoutes }
            let viableOptions = options.filter { RouteIncidentMatcher.avoids(incidents, on: $0) }
            guard !viableOptions.isEmpty else {
                errorMessage = "No alternate route avoids the reported crash. Stay alert and follow road signs."
                isLoading = false
                return false
            }
            activeScoring = liveScoring
            origin = location
            originCoordinate = location
            originName = "Your location"
            selectedRouteID = nil
            await analyze(viableOptions)
            isLoading = false
            return true
        } catch {
            errorMessage = "Couldn’t reroute. Your current route is still active."
            isLoading = false
            return false
        }
    }

    func swapEndpoints() async {
        let previousOrigin = originCoordinate
        let previousOriginName = originName
        await routeTo(destination: previousOrigin, name: previousOriginName,
                      origin: destinationCoordinate, originName: destinationName)
    }

    func rerank(selectRecommended: Bool = false) {
        if case .unavailable = crashDataStatus {
            rankedRoutes = routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
                .enumerated()
                .map { RankedRoute(route: $0.element, rank: $0.offset + 1, preferenceCost: 0) }
        } else {
            rankedRoutes = activeScoring.rank(routes, preference: riskPreference)
        }
        if selectRecommended { selectedRouteID = rankedRoutes.first?.route.id }
    }

    private func reanalyze() async { guard !routes.isEmpty else { return }; await analyze(routes) }

    private func loadDefaultRoute() async {
        await routeTo(destination: DemoRoutes.destination, name: DemoRoutes.destinationName, origin: DemoRoutes.origin, originName: DemoRoutes.originName)
    }

    private func analyze(_ rawRoutes: [NavigationRoute]) async {
        isLoading = true
        crashDataStatus = await activeScoring.refreshData(for: rawRoutes)
        var analyzed = await rawRoutes.asyncMap { await activeScoring.analyze($0, departure: self.departure, mode: self.mode) }
        labelAlternatives(&analyzed)
        routes = analyzed
        let needsRecommendation = selectedRouteID == nil || !analyzed.contains(where: { $0.id == selectedRouteID })
        rerank(selectRecommended: needsRecommendation)
        isLoading = false
    }

    private func labelAlternatives(_ routes: inout [NavigationRoute]) {
        guard routes.count > 1 else { return }
        for index in routes.indices { routes[index].kind = .balanced }
        guard let fastest = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }),
              let lowestExposure = routes.indices.min(by: { routes[$0].exposure.score < routes[$1].exposure.score }) else { return }
        routes[fastest].kind = .fastest
        if case .unavailable = crashDataStatus { return }
        if lowestExposure != fastest { routes[lowestExposure].kind = .lowerExposure }
    }
}

private enum RoutingError: Error { case noRoutes }
