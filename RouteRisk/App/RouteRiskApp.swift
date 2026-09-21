import SwiftUI

@main
struct RouteRiskApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var viewModel = NavigationViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(locationService)
                .environmentObject(viewModel)
        }
    }
}
