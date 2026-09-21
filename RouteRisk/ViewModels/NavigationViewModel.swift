import CoreLocation
import Foundation

@MainActor
final class NavigationViewModel: ObservableObject {
    @Published private(set) var routes: [NavigationRoute] = []
    @Published private(set) var rankedRoutes: [RankedRoute] = []
    @Published var selectedRouteID: UUID?
    @Published var riskPreference: Double = 0.5 { didSet { rerank() } }
    @Published var departure: DeparturePeriod = .daytime { didSet { Task { await reanalyze() } } }
    @Published var mode: TravelMode = .driving { didSet { Task { await reanalyze() } } }
    @Published var destinationName = DemoRoutes.destinationName
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var usesDemoData = true

    private let scoring: RiskScoringService
    private let routingService: any RoutingService
    private var origin = DemoRoutes.origin

    init(scoring: RiskScoringService = RiskScoringService(), routingService: any RoutingService = MapRoutingService()) {
        self.scoring = scoring
        self.routingService = routingService
        Task { await loadDemo() }
    }

    var selectedRoute: NavigationRoute? { routes.first { $0.id == selectedRouteID } }

    func loadDemo() async {
        usesDemoData = true
        origin = DemoRoutes.origin
        destinationName = DemoRoutes.destinationName
        await analyze(DemoRoutes.routes())
    }

    func routeTo(destination: CLLocationCoordinate2D, name: String, origin: CLLocationCoordinate2D?) async {
        isLoading = true
        errorMessage = nil
        self.origin = origin ?? DemoRoutes.origin
        destinationName = name
        do {
            let options = try await routingService.routes(from: self.origin, to: destination, mode: mode)
            guard !options.isEmpty else { throw RoutingError.noRoutes }
            usesDemoData = false
            await analyze(options)
        } catch {
            errorMessage = "Couldn’t find route alternatives. Showing the offline New Jersey demo instead."
            await loadDemo()
        }
        isLoading = false
    }

    func select(_ route: NavigationRoute) { selectedRouteID = route.id }

    func rerank() { rankedRoutes = scoring.rank(routes, preference: riskPreference) }

    private func reanalyze() async { guard !routes.isEmpty else { return }; await analyze(routes) }

    private func analyze(_ rawRoutes: [NavigationRoute]) async {
        isLoading = true
        let analyzed = await rawRoutes.asyncMap { await self.scoring.analyze($0, departure: self.departure, mode: self.mode) }
        routes = analyzed
        if selectedRouteID == nil || !analyzed.contains(where: { $0.id == selectedRouteID }) { selectedRouteID = analyzed.first?.id }
        rerank()
        isLoading = false
    }
}

private enum RoutingError: Error { case noRoutes }
