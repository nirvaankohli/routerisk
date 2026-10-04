import SwiftUI

struct NavigationHomeView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @State private var showingDetails = false
    @State private var showingSettings = false
    @State private var showingDestinationSearch = false
    @State private var editingEndpoint: RouteEndpoint = .destination
    @State private var showingRouteOptions = false
    @State private var routeSheetExpanded = true
    @State private var usesSatelliteMap = true
    @State private var recenterToken = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(
                routes: viewModel.routes,
                selectedRoute: viewModel.selectedRoute,
                showsUserLocation: true,
                usesSatelliteMap: usesSatelliteMap,
                centerCoordinate: locationService.currentLocation,
                recenterToken: recenterToken,
                destination: viewModel.destinationCoordinate,
                destinationName: viewModel.destinationName
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showingRouteOptions {
                    RouteEndpointPanel(
                        originName: viewModel.originName,
                        destinationName: viewModel.destinationName,
                        changeOrigin: { editingEndpoint = .origin; showingDestinationSearch = true },
                        changeDestination: { editingEndpoint = .destination; showingDestinationSearch = true }
                    )
                } else {
                    SearchDock(isPresented: $showingDestinationSearch) {
                        editingEndpoint = .destination
                    }
                }
                Spacer()
                VStack(spacing: 12) {
                    mapControl(symbol: usesSatelliteMap ? "map" : "globe.americas.fill", label: "Change map style") {
                        usesSatelliteMap.toggle()
                    }
                    mapControl(symbol: "location.fill", label: "Center on my location") {
                        locationService.requestLocation()
                        recenterToken = UUID()
                    }
                }
                .padding(.trailing, 18)
                .padding(.bottom, activePanelHeight + 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .frame(maxHeight: .infinity, alignment: .top)

            if showingRouteOptions {
                RouteComparisonSheet(showingDetails: $showingDetails, isExpanded: $routeSheetExpanded)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                RecentCrashesSheet(showingSettings: $showingSettings) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        routeSheetExpanded = true
                        showingRouteOptions = true
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .sheet(isPresented: $showingDetails) { RouteDetailView().environmentObject(viewModel) }
        .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(viewModel) }
        .fullScreenCover(isPresented: $showingDestinationSearch) {
            DestinationSearchView(endpoint: editingEndpoint) {
                withAnimation(.easeOut(duration: 0.22)) {
                    routeSheetExpanded = true
                    showingRouteOptions = true
                }
            }
        }
        .task { locationService.requestLocation() }
    }

    private func mapControl(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RouteRiskTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var activePanelHeight: CGFloat {
        if showingRouteOptions { return routeSheetExpanded ? 575 : 118 }
        return 286
    }
}

private struct RouteEndpointPanel: View {
    let originName: String
    let destinationName: String
    let changeOrigin: () -> Void
    let changeDestination: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: changeOrigin) {
                HStack(spacing: 13) {
                    Image(systemName: "location.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(RouteRiskTheme.action)
                        .frame(width: 30)
                    Text(originName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RouteRiskTheme.subduedText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change starting location")
            .accessibilityHint("Opens search to choose a new starting point")
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Button(action: changeDestination) {
                HStack(spacing: 13) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.86))
                        .frame(width: 30)
                    Text(destinationName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body.weight(.bold))
                        .foregroundStyle(RouteRiskTheme.subduedText)
                        .frame(width: 38, height: 38)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change destination")
            .accessibilityHint("Opens search to choose a new destination")
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
        .background(RouteRiskTheme.surface.opacity(0.98), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(alignment: .center) {
            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(height: 1)
                .padding(.leading, 62)
        }
        .shadow(color: .black.opacity(0.30), radius: 16, y: 7)
        .accessibilityElement(children: .contain)
    }
}

private struct RecentCrashesSheet: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Binding var showingSettings: Bool
    let showRouteOptions: () -> Void

    private var segments: [SegmentExposure] {
        (viewModel.selectedRoute?.exposure.segments ?? [])
            .filter { $0.crashCount > 0 }
            .sorted { lhs, rhs in
                if lhs.level != rhs.level { return lhs.level > rhs.level }
                return lhs.crashCount > rhs.crashCount
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.32))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 15)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent crashes")
                        .font(.title2.weight(.bold))
                    Text("Historical reports near your selected route")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Button(action: showRouteOptions) {
                    Label("Routes", systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows route comparison options")
            }
            .padding(.horizontal, 22)

            if segments.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(segments.prefix(2)) { segment in
                        crashRow(segment)
                    }
                }
                .padding(.top, 12)
            }

            Spacer(minLength: 8)
            bottomNavigation
        }
        .frame(maxWidth: .infinity)
        .frame(height: 286, alignment: .top)
        .safeAreaPadding(.bottom, 4)
        .background(Color(red: 0.035, green: 0.05, blue: 0.08))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 18, y: -5)
        .accessibilityElement(children: .contain)
    }

    private func crashRow(_ segment: SegmentExposure) -> some View {
        HStack(spacing: 12) {
            Image(systemName: segment.level.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(segment.level == .lower ? RouteRiskTheme.accent : .orange)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(segment.segment.roadName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(segment.crashCount) historical reports · \(segment.level.title) exposure")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.crashDataStatus.systemImage)
                .foregroundStyle(RouteRiskTheme.accent)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.10), in: Circle())
            Text(viewModel.crashDataStatus.detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            navigationItem("map.fill", title: "Explore", isSelected: true) {}
            navigationItem("person.crop.circle", title: "Profile", isSelected: false) { showingSettings = true }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color(red: 0.055, green: 0.075, blue: 0.10))
    }

    private func navigationItem(_ symbol: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 32)
                    .background(isSelected ? RouteRiskTheme.accent.opacity(0.19) : .clear, in: Capsule())
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? RouteRiskTheme.accent : .white.opacity(0.64))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
