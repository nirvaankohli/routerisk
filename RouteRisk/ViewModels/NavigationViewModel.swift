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
    @Published private(set) var originName = "Your location"
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

    func loadDemo() async {
        activeScoring = RiskScoringService(provider: SampleCrashDataProvider())
        origin = DemoRoutes.origin
        originCoordinate = DemoRoutes.origin
        originName = "Your location"
        destinationName = DemoRoutes.destinationName
        destinationCoordinate = DemoRoutes.destination
        await analyze(DemoRoutes.routes())
    }

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
            errorMessage = "Couldn’t find route alternatives. Showing the offline New Jersey demo instead."
            await loadDemo()
        }
        isLoading = false
    }

    func select(_ route: NavigationRoute) { selectedRouteID = route.id }

    func rerank(selectRecommended: Bool = false) {
        rankedRoutes = activeScoring.rank(routes, preference: riskPreference)
        if selectRecommended { selectedRouteID = rankedRoutes.first?.route.id }
    }

    private func reanalyze() async { guard !routes.isEmpty else { return }; await analyze(routes) }

    private func loadDefaultRoute() async {
        await routeTo(destination: DemoRoutes.destination, name: DemoRoutes.destinationName, origin: DemoRoutes.origin)
    }

    private func analyze(_ rawRoutes: [NavigationRoute]) async {
        isLoading = true
        crashDataStatus = await activeScoring.refreshData(for: rawRoutes)
        var analyzed = await rawRoutes.asyncMap { await activeScoring.analyze($0, departure: self.departure, mode: self.mode) }
        labelAlternatives(&analyzed)
        routes = analyzed
        if selectedRouteID == nil || !analyzed.contains(where: { $0.id == selectedRouteID }) { selectedRouteID = analyzed.first?.id }
        rerank()
        isLoading = false
    }

    private func labelAlternatives(_ routes: inout [NavigationRoute]) {
        guard routes.count > 1 else { return }
        for index in routes.indices { routes[index].kind = .balanced }
        guard let fastest = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }),
              let lowestExposure = routes.indices.min(by: { routes[$0].exposure.score < routes[$1].exposure.score }) else { return }
        routes[fastest].kind = .fastest
        if lowestExposure != fastest { routes[lowestExposure].kind = .lowerExposure }
    }
}

private enum RoutingError: Error { case noRoutes }
