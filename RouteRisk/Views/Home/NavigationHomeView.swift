import SwiftUI

struct NavigationHomeView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @State private var showingDetails = false
    @State private var showingSettings = false
    @State private var showingDestinationSearch = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(routes: viewModel.routes, selectedRoute: viewModel.selectedRoute, showsUserLocation: true)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROUTERISK").font(.caption2.weight(.heavy)).tracking(1.3).foregroundStyle(.blue)
                        Text("Know the risk before you take the route.").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 42, height: 42).background(.regularMaterial, in: Circle()) }
                        .accessibilityLabel("Route settings")
                }
                SearchDock(isPresented: $showingDestinationSearch)
                HStack(spacing: 9) {
                    Button { locationService.requestLocation() } label: { Image(systemName: "location.fill").frame(width: 42, height: 42).background(.regularMaterial, in: Circle()) }
                        .accessibilityLabel("Use current location")
                    Spacer()
                    DepartureMenu()
                    ModeMenu()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)

            RouteComparisonSheet(showingDetails: $showingDetails)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .sheet(isPresented: $showingDetails) { RouteDetailView().environmentObject(viewModel) }
        .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(viewModel) }
        .fullScreenCover(isPresented: $showingDestinationSearch) { DestinationSearchView() }
        .task { locationService.requestLocation() }
    }
}

private struct DepartureMenu: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    var body: some View {
        Menu {
            Picker("Departure", selection: $viewModel.departure) {
                ForEach(DeparturePeriod.allCases) { period in Label(period.title, systemImage: period.symbol).tag(period) }
            }
        } label: {
            Label(viewModel.departure.title, systemImage: viewModel.departure.symbol).font(.subheadline.weight(.semibold)).padding(.horizontal, 13).frame(height: 42).background(.regularMaterial, in: Capsule())
        }
        .accessibilityLabel("Departure period, \(viewModel.departure.title)")
    }
}

private struct ModeMenu: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    var body: some View {
        Menu {
            Picker("Travel mode", selection: $viewModel.mode) {
                ForEach(TravelMode.allCases) { mode in Label(mode.title, systemImage: mode.symbol).tag(mode) }
            }
        } label: {
            Image(systemName: viewModel.mode.symbol).frame(width: 42, height: 42).background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel("Travel mode, \(viewModel.mode.title)")
    }
}
