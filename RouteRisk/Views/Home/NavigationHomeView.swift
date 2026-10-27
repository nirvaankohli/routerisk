import AVFoundation
import CoreLocation
import SwiftUI
import UIKit

struct NavigationHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @AppStorage("parentPhoneNumber") private var parentPhoneNumber = ""
    @AppStorage("tripUpdatesEnabled") private var tripUpdatesEnabled = false
    @AppStorage("impactAlertsEnabled") private var impactAlertsEnabled = false
    @AppStorage("liveIncidentAlertsEnabled") private var liveIncidentAlertsEnabled = true
    @AppStorage("routeRisk.guidedShowcaseEnabled") private var guidedShowcaseEnabled = false
    @AppStorage("routeRisk.homeName") private var homeName = ""
    @AppStorage("routeRisk.homeLatitude") private var homeLatitude = 0.0
    @AppStorage("routeRisk.homeLongitude") private var homeLongitude = 0.0
    @AppStorage("routeRisk.workName") private var workName = ""
    @AppStorage("routeRisk.workLatitude") private var workLatitude = 0.0
    @AppStorage("routeRisk.workLongitude") private var workLongitude = 0.0
    @AppStorage("routeRisk.schoolName") private var schoolName = ""
    @AppStorage("routeRisk.schoolLatitude") private var schoolLatitude = 0.0
    @AppStorage("routeRisk.schoolLongitude") private var schoolLongitude = 0.0
    @AppStorage("routeRisk.recentDestinations") private var storedRecents = ""
    @StateObject private var impactMonitor = TripImpactMonitor()
    @StateObject private var recentSearch = DestinationSearchService()
    @State private var showingDetails = false
    @State private var showingSettings = false
    @State private var searchPresentation: SearchPresentation?
    @State private var homePanelExpanded = false
    @State private var resolvingRecent: String?
    @State private var routeSheetExpanded = true
    @State private var directionsVisible = true
    @State private var selectedDirectionsMode: DirectionsMode = .car
    @State private var usesSatelliteMap = true
    @State private var recenterToken = UUID()
    @State private var followingRouteID: UUID?
    @State private var activeStop: TripStop?
    @State private var routeActionInProgress = false
    @State private var routeActionMessage: String?
    @State private var arrivalNotifiedRouteID: UUID?
    @State private var pendingSafetyMessage: SafetyMessage?
    @State private var safetyStatus: String?
    @State private var crashCountdown = 20
    @State private var countdownTask: Task<Void, Never>?
    @State private var incidentSpeaker = AVSpeechSynthesizer()
    @State private var activeIncidentAlert: RouteIncidentAlert?
    @State private var crashWarning: CrashWarning?
    @State private var crashWarningTask: Task<Void, Never>?
    @State private var latestIncidents: [LiveRoadIncident] = []
    @State private var seenIncidentIDs: Set<String> = []
    @State private var incidentStatus = "Checking 511NJ crash reports…"
    @State private var didUseCurrentLocationForOrigin = false
    @State private var showcaseRoute: NavigationRoute?
    @State private var showcaseDetour: NavigationRoute?
    @State private var showcaseLocation: CLLocationCoordinate2D?
    @State private var showcaseHeading: Double?
    @State private var showcaseIncident: CLLocationCoordinate2D?
    @State private var showcaseReroutePrompt = false
    @State private var showcaseDriveTask: Task<Void, Never>?
    @State private var showcaseDecisionTask: Task<Void, Never>?
    @State private var priorTrip: (destination: CLLocationCoordinate2D, name: String, origin: CLLocationCoordinate2D, originName: String)?

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(
                routes: followingRoute.map { [$0] } ?? (directionsVisible && selectedDirectionsMode == .car ? viewModel.routes : []),
                selectedRoute: followingRoute ?? (directionsVisible && selectedDirectionsMode == .car ? viewModel.selectedRoute : nil),
                showsExposure: hasExposureData,
                showsDestination: followingRoute != nil || directionsVisible,
                showsUserLocation: !guidedShowcaseEnabled && locationService.currentLocation != nil,
                isNavigating: followingRoute != nil,
                followsUser: followingRoute != nil && followingStatus?.isOnRoute == true,
                usesSatelliteMap: usesSatelliteMap,
                centerCoordinate: displayedLocation,
                reportedIncidents: relevantIncidents,
                animatedLocation: guidedShowcaseEnabled ? showcaseLocation : nil,
                animatedHeading: guidedShowcaseEnabled ? showcaseHeading : nil,
                practiceCrashCoordinate: guidedShowcaseEnabled ? showcaseIncident : nil,
                recenterToken: recenterToken,
                destination: viewModel.destinationCoordinate,
                destinationName: viewModel.destinationName,
                stop: followingRoute != nil ? activeStop : nil
            )
                .ignoresSafeArea()

            if followingRoute == nil && directionsVisible {
                RouteComparisonSheet(showingDetails: $showingDetails, isExpanded: $routeSheetExpanded, selectedMode: $selectedDirectionsMode, onClose: {
                    withAnimation(.easeOut(duration: 0.22)) { directionsVisible = false }
                }) { route in
                    if guidedShowcaseEnabled {
                        Task { await startShowcase() }
                        return
                    }
                    withAnimation(.easeOut(duration: 0.22)) { followingRouteID = route.id }
                    usesSatelliteMap = false
                    locationService.startFollowingRoute()
                    recenterToken = UUID()
                    arrivalNotifiedRouteID = nil
                    safetyStatus = nil
                    activeIncidentAlert = nil
                    crashWarningTask?.cancel()
                    crashWarning = nil
                    latestIncidents = []
                    seenIncidentIDs = []
                    incidentStatus = "Checking 511NJ crash reports…"
                    activeStop = nil
                    routeActionMessage = nil
                    updateImpactMonitoring()
                    sendTripUpdate(.departure, route: route)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }

            if followingRoute == nil && !directionsVisible {
                homePanel
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            if followingRoute != nil || directionsVisible || !homePanelExpanded {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        if followingRoute != nil {
                            Button {
                                if guidedShowcaseEnabled { showingSettings = true }
                                else { Task { await reroute(via: activeStop) } }
                            } label: {
                                Image(systemName: guidedShowcaseEnabled ? "gearshape" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(RouteRiskTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
                            }
                            .buttonStyle(.plain)
                            .disabled(routeActionInProgress)
                            .accessibilityLabel(guidedShowcaseEnabled ? "Presentation settings" : "Reroute from current location")
                        }
                        mapControl(icon: usesSatelliteMap ? "MuiMapOutlined" : "MuiLayersOutlined", label: "Change map style") {
                            usesSatelliteMap.toggle()
                        }
                        mapControl(icon: "MuiMyLocation", label: "Center on my location") {
                            if !guidedShowcaseEnabled { locationService.requestLocation() }
                            if displayedLocation != nil { recenterToken = UUID() }
                        }
                    }
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, activePanelHeight + 16)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
                .transition(.opacity)
            }

            if followingRoute != nil, let status = followingStatus {
                VStack(spacing: 0) {
                    Group {
                        if showcaseReroutePrompt {
                            showcaseRerouteCard
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let crashWarning {
                            crashWarningCard(crashWarning)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            guidancePanel(status: status)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    Spacer()
                    tripPanel(status: status)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else if directionsVisible {
                VStack {
                    RouteEndpointPanel(
                        originName: viewModel.originName,
                        destinationName: viewModel.destinationName,
                        changeOrigin: { prepareSearch(endpoint: .origin) },
                        changeDestination: { prepareSearch() },
                        showSettings: { showingSettings = true },
                        swapEndpoints: { Task { await viewModel.swapEndpoints() } }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack {
                    HStack(spacing: 0) {
                        SearchDock { prepareSearch() }
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 1, height: 30)
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    .background(RouteRiskTheme.surface, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.26), lineWidth: 1)
                    }
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .frame(maxHeight: .infinity, alignment: .top)
            }

        }
        .sheet(isPresented: $showingDetails) { RouteDetailView().environmentObject(viewModel) }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onStartShowcase: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Task { await startShowcase() } }
            }, onStopShowcase: { stopShowcase() })
                .environmentObject(viewModel)
        }
        .sheet(item: $pendingSafetyMessage) { SafetyMessageSheet(message: $0) }
        .alert("Possible crash detected", isPresented: $impactMonitor.suspectedImpact) {
            Button("I'm okay", role: .cancel) { cancelImpactAlert() }
            Button("Call parent now") { contactParentAfterImpact() }
        } message: {
            Text("A strong impact and sudden stop may indicate a crash. Cancel if you're okay. Parent contact begins in \(crashCountdown) seconds.")
        }
        .fullScreenCover(item: $searchPresentation) { presentation in
            DestinationSearchView(endpoint: presentation.endpoint, saveTarget: presentation.saveTarget, savesWithoutRouting: presentation.saveTarget != nil, focusesOnAppear: presentation.focusesOnAppear, initialQuery: presentation.initialQuery, onStopSelected: { stop in
                await reroute(via: stop)
            }) {
                withAnimation(.easeOut(duration: 0.22)) {
                    routeSheetExpanded = true
                    directionsVisible = true
                    selectedDirectionsMode = .car
                }
            }
            .environmentObject(locationService)
        }
        .onChange(of: locationService.currentSpeed) { _, speed in impactMonitor.observeSpeed(speed) }
        .onReceive(locationService.$currentLocation) { coordinate in
            if !guidedShowcaseEnabled, let coordinate {
                evaluateIncidents(from: coordinate)
                useCurrentLocationForOriginIfNeeded(coordinate)
            }
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !guidedShowcaseEnabled, !loading, let coordinate = locationService.currentLocation {
                useCurrentLocationForOriginIfNeeded(coordinate)
            }
        }
        .onChange(of: followingStatus?.hasArrived) { _, arrived in
            guard !guidedShowcaseEnabled, arrived == true, let route = followingRoute, arrivalNotifiedRouteID != route.id else { return }
            arrivalNotifiedRouteID = route.id
            sendTripUpdate(.arrival, route: route)
        }
        .onChange(of: scenePhase) { _, _ in updateImpactMonitoring() }
        .onChange(of: guidedShowcaseEnabled) { _, enabled in
            if !enabled { stopShowcase() }
        }
        .onChange(of: impactMonitor.suspectedImpact) { _, suspected in
            if suspected {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                startImpactCountdown()
            }
            else { countdownTask?.cancel() }
        }
        .task(id: followingRouteID) { await monitorLiveIncidents() }
        .task {
            if guidedShowcaseEnabled { await startShowcase() }
            else { locationService.requestLocation() }
        }
        .task(id: homePanelExpanded) {
            if homePanelExpanded { await fillRecentSubtitles() }
        }
    }

    private var followingRoute: NavigationRoute? {
        if showcaseRoute?.id == followingRouteID { return showcaseRoute }
        return viewModel.routes.first { $0.id == followingRouteID }
    }

    private var displayedLocation: CLLocationCoordinate2D? {
        guidedShowcaseEnabled ? showcaseLocation : locationService.currentLocation
    }

    private var relevantIncidents: [LiveRoadIncident] {
        guard !guidedShowcaseEnabled, let route = followingRoute, let location = locationService.currentLocation else { return [] }
        return RouteIncidentMatcher.ahead(latestIncidents, on: route, from: location).map(\.incident)
    }

    private func useCurrentLocationForOriginIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        guard !didUseCurrentLocationForOrigin,
              !guidedShowcaseEnabled,
              !viewModel.isLoading,
              followingRouteID == nil,
              viewModel.originName == DemoRoutes.originName else { return }
        didUseCurrentLocationForOrigin = true
        Task {
            await viewModel.routeTo(
                destination: viewModel.destinationCoordinate,
                name: viewModel.destinationName,
                origin: coordinate,
                originName: "Your location"
            )
        }
    }

    private var recentPlaces: [RecentPlace] {
        RecentPlace.decode(storedRecents)
    }

    private var homePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .accessibilityElement()
                    .accessibilityLabel("Places panel")
                    .accessibilityAction(named: homePanelExpanded ? "Hide recents" : "Show recents") {
                        withAnimation(.easeOut(duration: 0.22)) { homePanelExpanded.toggle() }
                    }

                HStack {
                Button {
                    prepareSearch(focusesOnAppear: false)
                } label: {
                    HStack(spacing: 7) {
                        Text("Places")
                            .font(.title2.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RouteRiskTheme.subduedText)
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show places")
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.22)) {
                        homePanelExpanded = false
                        routeSheetExpanded = true
                        directionsVisible = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        MaterialIcon(name: "MuiDirectionsCar", size: 19)
                        Text("Directions")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RouteRiskTheme.action)
                    .frame(height: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open directions")
                }

                PlaceShortcutRow(
                    homeDetail: homeName.isEmpty ? "Not set" : homeName,
                    workDetail: workName.isEmpty ? "Not set" : workName,
                    schoolDetail: schoolName.isEmpty ? "Not set" : schoolName,
                    onHome: { openSavedPlace(.home) },
                    onWork: { openSavedPlace(.work) },
                    onSchool: { openSavedPlace(.school) },
                    onAdd: { prepareSearch(saveTarget: .custom) }
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    guard abs(value.translation.height) > 45 else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        homePanelExpanded = value.translation.height < 0
                    }
                }
            )

            if homePanelExpanded {
                recentPlacesSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(RouteRiskTheme.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: -4)
    }

    private var recentPlacesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                prepareSearch(focusesOnAppear: false)
            } label: {
                HStack(spacing: 7) {
                    Text("Recents")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RouteRiskTheme.subduedText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show all recents")

            if recentPlaces.isEmpty {
                Text("Places you search for will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(RouteRiskTheme.subduedText)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(20)
                    .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(recentPlaces) { place in
                            HStack(spacing: 0) {
                                Button { openRecentPlace(place) } label: {
                                    HStack(spacing: 14) {
                                        MaterialIcon(name: "MuiPlaceOutlined", size: 23)
                                            .foregroundStyle(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color(red: 0.42, green: 0.46, blue: 0.55), in: Circle())
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(place.name)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text(place.subtitle.isEmpty ? "Recent destination" : place.subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(RouteRiskTheme.subduedText)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        if resolvingRecent == place.name { ProgressView() }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .padding(.leading, 16)
                                }
                                .buttonStyle(.plain)

                                Menu {
                                    Button("Remove from Recents", role: .destructive) { removeRecentPlace(place) }
                                } label: {
                                    MaterialIcon(name: "MuiMoreHoriz", size: 26)
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 76)
                                }
                                .accessibilityLabel("More options for \(place.name)")
                            }
                            .frame(height: 76)
                            if place.id != recentPlaces.last?.id {
                                Divider().padding(.leading, 74).padding(.trailing, 16)
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(recentPlaces.count) * 77, 290))
                .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private func prepareSearch(endpoint: RouteEndpoint = .destination, saveTarget: SavedPlaceKind? = nil, focusesOnAppear: Bool = true, initialQuery: String = "") {
        searchPresentation = SearchPresentation(endpoint: endpoint, saveTarget: saveTarget, focusesOnAppear: focusesOnAppear, initialQuery: initialQuery)
    }

    private func removeRecentPlace(_ place: RecentPlace) {
        storedRecents = RecentPlace.encode(recentPlaces.filter { $0.id != place.id })
    }

    private func fillRecentSubtitles() async {
        for place in recentPlaces where place.subtitle.isEmpty {
            guard !Task.isCancelled,
                  let subtitle = try? await recentSearch.subtitle(query: place.name),
                  !subtitle.isEmpty else { continue }
            var places = recentPlaces
            guard let index = places.firstIndex(where: { $0.id == place.id }), places[index].subtitle.isEmpty else { continue }
            places[index] = RecentPlace(name: place.name, subtitle: subtitle)
            storedRecents = RecentPlace.encode(places)
        }
    }

    private func openRecentPlace(_ place: RecentPlace) {
        guard resolvingRecent == nil else { return }
        resolvingRecent = place.name
        Task {
            defer { resolvingRecent = nil }
            guard let result = try? await recentSearch.resolve(query: place.name) else {
                prepareSearch(initialQuery: place.name)
                return
            }
            await viewModel.routeTo(destination: result.coordinate, name: result.title, origin: viewModel.originCoordinate, originName: viewModel.originName)
            withAnimation(.easeOut(duration: 0.22)) {
                homePanelExpanded = false
                routeSheetExpanded = true
                selectedDirectionsMode = .car
                directionsVisible = true
            }
        }
    }

    private func openSavedPlace(_ place: SavedPlaceKind) {
        let saved: (name: String, latitude: Double, longitude: Double)
        switch place {
        case .home: saved = (homeName, homeLatitude, homeLongitude)
        case .work: saved = (workName, workLatitude, workLongitude)
        case .school: saved = (schoolName, schoolLatitude, schoolLongitude)
        case .custom: return
        }
        guard !saved.name.isEmpty else {
            prepareSearch(saveTarget: place)
            return
        }
        Task {
            await viewModel.routeTo(destination: CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude), name: saved.name, origin: viewModel.originCoordinate, originName: viewModel.originName)
            withAnimation(.easeOut(duration: 0.22)) {
                homePanelExpanded = false
                routeSheetExpanded = true
                selectedDirectionsMode = .car
                directionsVisible = true
            }
        }
    }

    private var followingStatus: RouteFollowingStatus? {
        guard let route = followingRoute else { return nil }
        return RouteFollowingStatus(route: route, location: displayedLocation,
                                    authorization: guidedShowcaseEnabled ? .authorizedWhenInUse : locationService.authorizationStatus)
    }

    private func guidancePanel(status: RouteFollowingStatus) -> some View {
        VStack(spacing: -40) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: status.maneuver.symbolName)
                    .font(.system(size: 40, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RouteRiskTheme.action)
                    .frame(width: 56, height: 64)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    if let distanceToManeuver = status.distanceToManeuver {
                        Text(distanceToManeuver)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(RouteRiskTheme.action)
                    }
                    Text(status.instruction)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = status.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(RouteRiskTheme.subduedText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.02, green: 0.07, blue: 0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .zIndex(1)

            if let nextInstruction = status.nextInstruction, let nextManeuver = status.nextManeuver {
                HStack(spacing: 12) {
                    Image(systemName: nextManeuver.symbolName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.isOnRoute
                             ? "THEN\(status.nextDistance.map { " · \($0)" } ?? "")"
                             : "ON THE ROUTE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.62))
                        Text(nextInstruction)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 49)
                .padding(.bottom, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.06, green: 0.13, blue: 0.14), in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                ))
            }
        }
    }

    private func crashWarningCard(_ warning: CrashWarning) -> some View {
        HStack(spacing: 16) {
            Image(systemName: warning.symbol)
                .font(.system(size: 32, weight: .semibold))
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(.title2.weight(.bold))
                Text(warning.detail)
                    .font(.subheadline.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.04))
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color(red: 0.95, green: 0.70, blue: 0.23), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var showcaseRerouteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Crash reported ahead")
                        .font(.title2.weight(.bold))
                    Text("Practice report · Reroute around it?")
                        .font(.subheadline.weight(.medium))
                }
            }
            HStack(spacing: 10) {
                Button("No, keep route") {
                    showcaseDecisionTask?.cancel()
                    withAnimation(.easeOut(duration: 0.22)) { showcaseReroutePrompt = false }
                    showCrashWarning(title: "Route unchanged", detail: "Continue with caution near the practice report.")
                    if let route = showcaseRoute, let location = showcaseLocation,
                       let position = Geographic.position(on: route.segments, near: location) {
                        showcaseDriveTask = Task { @MainActor in
                            _ = await advanceShowcase(on: route, from: position.progress, to: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.black.opacity(0.12), in: Capsule())
                Button("Yes, reroute") { acceptShowcaseReroute() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.13, green: 0.10, blue: 0.04), in: Capsule())
                    .foregroundStyle(.white)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.04))
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.70, blue: 0.23), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
    }

    private func tripPanel(status: RouteFollowingStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                HStack(alignment: .top, spacing: 8) {
                    tripMetric(value: status.isOnRoute
                               ? timeline.date.addingTimeInterval(TimeInterval(status.remainingMinutes * 60)).formatted(date: .omitted, time: .shortened)
                               : "—", label: "arrival")
                    tripMetric(value: "\(status.remainingMinutes)", label: status.isOnRoute ? "min left" : "min route")
                    tripMetric(value: String(format: "%.1f", status.remainingMiles), label: status.isOnRoute ? "mi left" : "route mi")
                }
            }
            HStack(spacing: 12) {
                Button(action: endFollowing) {
                    Label("End Route", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 1.0, green: 0.29, blue: 0.36), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End navigation")
                if !guidedShowcaseEnabled {
                    tripAction(icon: "plus", title: activeStop == nil ? "Add stop" : "Change stop") {
                        guard locationService.currentLocation != nil else {
                            locationService.requestLocation()
                            routeActionMessage = "Waiting for your location to add a stop."
                            return
                        }
                        prepareSearch(endpoint: .stop)
                    }
                }
            }
            .disabled(routeActionInProgress)
            if let activeStop {
                HStack(spacing: 8) {
                    Label("Via \(activeStop.name)", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(RouteRiskTheme.subduedText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Remove") { Task { await reroute(via: nil) } }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RouteRiskTheme.action)
                        .disabled(routeActionInProgress)
                        .accessibilityLabel("Remove stop")
                }
            }
            if routeActionInProgress { ProgressView("Updating route…").font(.caption) }
            if let routeActionMessage { Text(routeActionMessage).font(.caption).foregroundStyle(.orange) }
            if let safetyStatus { Text(safetyStatus).font(.caption).foregroundStyle(RouteRiskTheme.subduedText) }
            if !guidedShowcaseEnabled && liveIncidentAlertsEnabled && incidentStatus.contains("unavailable") {
                Text(incidentStatus)
                    .font(.caption2)
                    .foregroundStyle(RouteRiskTheme.subduedText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 30,
                style: .continuous
            )
            .fill(Color(red: 0.035, green: 0.09, blue: 0.09))
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
    }

    private func tripMetric(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(value).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
            Text(label).font(.caption).foregroundStyle(RouteRiskTheme.subduedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func tripAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func endFollowing() {
        if guidedShowcaseEnabled {
            guidedShowcaseEnabled = false
            stopShowcase()
            return
        }
        let hadStop = activeStop != nil
        locationService.stopFollowingRoute()
        impactMonitor.stop()
        countdownTask?.cancel()
        impactMonitor.suspectedImpact = false
        activeIncidentAlert = nil
        crashWarningTask?.cancel()
        crashWarning = nil
        latestIncidents = []
        seenIncidentIDs = []
        activeStop = nil
        routeActionMessage = nil
        withAnimation(.easeOut(duration: 0.22)) { followingRouteID = nil }
        if hadStop, let location = locationService.currentLocation {
            Task { _ = await viewModel.reroute(from: location) }
        }
    }

    @MainActor private func startShowcase() async {
        guard guidedShowcaseEnabled else { return }
        showcaseDriveTask?.cancel()
        showcaseDecisionTask?.cancel()
        crashWarningTask?.cancel()
        if priorTrip == nil {
            priorTrip = (viewModel.destinationCoordinate, viewModel.destinationName,
                         viewModel.originCoordinate, viewModel.originName)
        }
        locationService.stopFollowingRoute()
        impactMonitor.stop()
        countdownTask?.cancel()
        impactMonitor.suspectedImpact = false
        followingRouteID = nil
        showcaseRoute = nil
        showcaseDetour = nil
        showcaseLocation = nil
        showcaseHeading = nil
        showcaseIncident = nil
        showcaseReroutePrompt = false
        crashWarning = nil
        activeIncidentAlert = nil
        latestIncidents = []
        seenIncidentIDs = []
        activeStop = nil
        routeActionMessage = nil

        await viewModel.routeTo(destination: DemoRoutes.destination, name: DemoRoutes.destinationName,
                                origin: DemoRoutes.origin, originName: DemoRoutes.originName)
        guard guidedShowcaseEnabled else { return }
        guard let primary = viewModel.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            return
        }
        guard let trigger = Geographic.coordinate(on: primary.segments, progress: 0.53) else { return }
        guard let scenario = await prepareShowcaseDetour(primary: primary, from: trigger) else {
            viewModel.errorMessage = "An alternate road route isn't available right now. Check your connection and try again."
            return
        }
        guard guidedShowcaseEnabled else { return }
        showcaseDetour = scenario.route
        showcaseRoute = primary
        showcaseLocation = Geographic.coordinate(on: primary.segments, progress: 0.50)
        showcaseHeading = Geographic.heading(on: primary.segments, progress: 0.50)
        directionsVisible = true
        usesSatelliteMap = false
        recenterToken = UUID()
        withAnimation(.easeOut(duration: 0.22)) { followingRouteID = primary.id }
        showcaseDriveTask = Task { @MainActor in
            guard await advanceShowcase(on: primary, from: 0.50, to: 0.53) else { return }
            showcaseIncident = scenario.crash
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            incidentSpeaker.stopSpeaking(at: .immediate)
            incidentSpeaker.speak(AVSpeechUtterance(string: "Crash reported ahead. Reroute around it?"))
            withAnimation(.easeInOut(duration: 0.22)) { showcaseReroutePrompt = true }
            showcaseDecisionTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(6)) } catch { return }
                showcaseDecisionTask = nil
                if showcaseReroutePrompt { acceptShowcaseReroute() }
            }
        }
    }

    @MainActor private func prepareShowcaseDetour(primary: NavigationRoute, from location: CLLocationCoordinate2D)
        async -> (route: NavigationRoute, crash: CLLocationCoordinate2D)? {
        let routing = MapRoutingService()
        var candidates = (try? await routing.routes(from: location, to: DemoRoutes.destination, mode: .driving)) ?? []
        let waypoints = [
            CLLocationCoordinate2D(latitude: 40.273, longitude: -74.755),
            CLLocationCoordinate2D(latitude: 40.286, longitude: -74.725),
            CLLocationCoordinate2D(latitude: 40.302, longitude: -74.711)
        ]
        for waypoint in waypoints {
            if let route = try? await routing.route(from: location, via: waypoint, to: DemoRoutes.destination, mode: .driving) {
                candidates.append(route)
            }
        }
        let viable = candidates.compactMap { candidate -> (route: NavigationRoute, crash: CLLocationCoordinate2D)? in
            for progress in [0.58, 0.62, 0.66, 0.70, 0.74] {
                guard let crash = Geographic.coordinate(on: primary.segments, progress: progress),
                      RouteIncidentMatcher.avoids([crash], on: candidate) else { continue }
                return (candidate, crash)
            }
            return nil
        }
        return viable.min { $0.route.expectedTravelTime < $1.route.expectedTravelTime }
    }

    @MainActor private func advanceShowcase(on route: NavigationRoute, from start: Double, to end: Double) async -> Bool {
        var progress = start
        let speed = ShowcaseMotion.metersPerSecond(for: route)
        while progress < end {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return false }
            guard guidedShowcaseEnabled, followingRouteID == route.id else { return false }
            progress = min(end, ShowcaseMotion.nextProgress(on: route.segments, from: progress, speed: speed, seconds: 0.5))
            showcaseLocation = Geographic.coordinate(on: route.segments, progress: progress)
            showcaseHeading = Geographic.heading(on: route.segments, progress: progress)
        }
        return true
    }

    private func acceptShowcaseReroute() {
        guard showcaseReroutePrompt, let route = showcaseDetour else { return }
        showcaseDecisionTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) { showcaseReroutePrompt = false }
        showCrashWarning(title: "Rerouting", detail: "Finding another way around the practice report.", symbol: "arrow.triangle.2.circlepath")
        showcaseDriveTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard guidedShowcaseEnabled else { return }
            showcaseRoute = route
            followingRouteID = route.id
            showcaseLocation = route.segments.first?.start
            showcaseHeading = Geographic.heading(on: route.segments, progress: 0)
            recenterToken = UUID()
            showCrashWarning(title: "New route ready", detail: "The route avoids the reported location.", symbol: "arrow.triangle.branch")
            _ = await advanceShowcase(on: route, from: 0, to: 1)
        }
    }

    private func stopShowcase() {
        guard showcaseRoute != nil || showcaseLocation != nil || showcaseDriveTask != nil || priorTrip != nil else { return }
        showcaseDriveTask?.cancel()
        showcaseDriveTask = nil
        showcaseDecisionTask?.cancel()
        showcaseDecisionTask = nil
        crashWarningTask?.cancel()
        showcaseReroutePrompt = false
        showcaseRoute = nil
        showcaseDetour = nil
        showcaseLocation = nil
        showcaseHeading = nil
        showcaseIncident = nil
        crashWarning = nil
        followingRouteID = nil
        activeIncidentAlert = nil
        latestIncidents = []
        locationService.stopFollowingRoute()
        if let priorTrip {
            self.priorTrip = nil
            let origin = locationService.currentLocation ?? priorTrip.origin
            let originName = locationService.currentLocation == nil ? priorTrip.originName : "Your location"
            Task {
                await viewModel.routeTo(destination: priorTrip.destination, name: priorTrip.name,
                                        origin: origin, originName: originName)
            }
        }
        locationService.requestLocation()
    }

    @MainActor private func reroute(via stop: TripStop?, avoiding incidents: [CLLocationCoordinate2D] = []) async {
        guard !guidedShowcaseEnabled else { return }
        guard !routeActionInProgress else { return }
        guard let location = locationService.currentLocation else {
            locationService.requestLocation()
            routeActionMessage = "Waiting for your location to reroute."
            if !incidents.isEmpty { showCrashWarning(title: "Crash ahead", detail: "Waiting for location to find another route.") }
            return
        }
        let previousRouteID = followingRouteID
        routeActionInProgress = true
        routeActionMessage = nil
        defer { routeActionInProgress = false }
        if await viewModel.reroute(from: location, via: stop, avoiding: incidents) {
            guard followingRouteID == previousRouteID, followingRouteID != nil else { return }
            followingRouteID = viewModel.selectedRouteID
            activeStop = stop
            activeIncidentAlert = nil
            latestIncidents = []
            recenterToken = UUID()
            if !incidents.isEmpty { showCrashWarning(title: "Route updated", detail: "New route avoids the reported crash location.", symbol: "arrow.triangle.branch") }
        } else {
            routeActionMessage = viewModel.errorMessage
            if !incidents.isEmpty { showCrashWarning(title: "Crash ahead", detail: "No clear alternate route. Follow road signs and use caution.") }
        }
    }

    private func monitorLiveIncidents() async {
        guard followingRoute != nil, !guidedShowcaseEnabled else { return }
        while !Task.isCancelled {
            if scenePhase == .active && liveIncidentAlertsEnabled && !guidedShowcaseEnabled {
                do {
                    let incidents = try await NJ511IncidentService().fetch()
                    guard !Task.isCancelled, followingRoute != nil else { return }
                    latestIncidents = incidents
                    if let location = locationService.currentLocation {
                        incidentStatus = "511NJ checked just now"
                        evaluateIncidents(from: location)
                    } else {
                        incidentStatus = "511NJ loaded · waiting for location"
                    }
                } catch {
                    latestIncidents = []
                    activeIncidentAlert = nil
                    incidentStatus = "511NJ incident feed unavailable"
                }
            }
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
        }
    }

    private func evaluateIncidents(from location: CLLocationCoordinate2D) {
        guard !guidedShowcaseEnabled, scenePhase == .active, liveIncidentAlertsEnabled, let route = followingRoute else { return }
        let matches = RouteIncidentMatcher.ahead(latestIncidents, on: route, from: location)
        if let current = activeIncidentAlert,
           !matches.contains(where: { $0.incident.id == current.incident.id }) {
            activeIncidentAlert = nil
        }
        guard !routeActionInProgress else { return }
        let newAlerts = matches.filter { !seenIncidentIDs.contains($0.incident.id) }
        seenIncidentIDs.formUnion(matches.map { $0.incident.id })
        guard let nearest = newAlerts.first else { return }
        presentIncident(nearest)
        Task { await reroute(via: activeStop, avoiding: matches.map(\.incident.coordinate)) }
    }

    private func presentIncident(_ alert: RouteIncidentAlert) {
        activeIncidentAlert = alert
        if followingRoute != nil {
            showCrashWarning(title: "Crash ahead", detail: "Looking for a route around the reported crash.")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        incidentSpeaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "Crash reported near your route ahead. Use caution.")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        incidentSpeaker.speak(utterance)
    }

    private func showCrashWarning(title: String, detail: String, symbol: String = "exclamationmark.triangle.fill") {
        crashWarningTask?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            crashWarning = CrashWarning(title: title, detail: detail, symbol: symbol)
        }
        crashWarningTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            withAnimation(.easeOut(duration: 0.22)) { crashWarning = nil }
        }
    }

    private func updateImpactMonitoring() {
        if !guidedShowcaseEnabled, scenePhase == .active, followingRoute != nil, impactAlertsEnabled,
           ParentContact.phoneNumber(from: parentPhoneNumber) != nil, !impactMonitor.suspectedImpact {
            impactMonitor.start()
            impactMonitor.observeSpeed(locationService.currentSpeed)
        } else {
            impactMonitor.stop()
        }
    }

    private func sendTripUpdate(_ event: SafetyEvent, route: NavigationRoute) {
        guard !guidedShowcaseEnabled, tripUpdatesEnabled,
              let parent = ParentContact.phoneNumber(from: parentPhoneNumber) else { return }
        let location = locationService.currentLocation
        let messageTime = event == .departure
            ? Date().addingTimeInterval(route.expectedTravelTime)
            : Date()
        let timeText = SafetyMessage.timeText(for: messageTime)
        let message = event == .departure
            ? SafetyMessage.departure(to: parent, destination: viewModel.destinationName, eta: timeText)
            : SafetyMessage.arrival(to: parent, destination: viewModel.destinationName, at: timeText)
        Task {
            let client = SafetyBackendClient()
            if client.isConfigured {
                do {
                    try await client.send(event, to: parent, destination: viewModel.destinationName,
                                          location: location, timeText: timeText)
                    safetyStatus = event == .departure ? "Departure update queued" : "Arrival update queued"
                    return
                } catch {
                    safetyStatus = "Automatic update failed. Send the prepared text."
                }
            }
            pendingSafetyMessage = message
        }
    }

    private func startImpactCountdown() {
        countdownTask?.cancel()
        crashCountdown = 20
        countdownTask = Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, impactMonitor.suspectedImpact else { return }
                crashCountdown -= 1
            }
            contactParentAfterImpact()
        }
    }

    private func cancelImpactAlert() {
        countdownTask?.cancel()
        impactMonitor.suspectedImpact = false
        updateImpactMonitoring()
    }

    private func contactParentAfterImpact() {
        countdownTask?.cancel()
        impactMonitor.suspectedImpact = false
        guard let parent = ParentContact.phoneNumber(from: parentPhoneNumber) else { return }
        let destination = viewModel.destinationName
        let location = locationService.currentLocation
        Task {
            let client = SafetyBackendClient()
            if client.isConfigured {
                do {
                    try await client.send(.possibleCrash, to: parent, destination: destination, location: location)
                    safetyStatus = "Parent alert queued"
                    return
                } catch {
                    safetyStatus = "Automatic alert failed. Confirm the call in Phone."
                }
            }
            guard let url = URL(string: "tel:\(parent)") else { return }
            openURL(url)
        }
    }

    private func mapControl(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MaterialIcon(name: icon, size: 22)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RouteRiskTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var activePanelHeight: CGFloat {
        if followingRoute != nil { return 205 }
        if !directionsVisible {
            if !homePanelExpanded { return 215 }
            return recentPlaces.isEmpty ? 410 : 330 + min(CGFloat(recentPlaces.count) * 77, 290)
        }
        return routeSheetExpanded ? RouteComparisonSheet.expandedHeight : RouteComparisonSheet.collapsedHeight
    }

    private var hasExposureData: Bool {
        if case .unavailable = viewModel.crashDataStatus { return false }
        return true
    }
}

private struct CrashWarning {
    let title: String
    let detail: String
    let symbol: String
}

private struct SearchPresentation: Identifiable {
    let id = UUID()
    let endpoint: RouteEndpoint
    let saveTarget: SavedPlaceKind?
    let focusesOnAppear: Bool
    let initialQuery: String
}

private struct RouteFollowingStatus {
    let maneuver: GuidanceManeuver
    let distanceToManeuver: String?
    let instruction: String
    let detail: String?
    let nextManeuver: GuidanceManeuver?
    let nextDistance: String?
    let nextInstruction: String?
    let remainingMinutes: Int
    let remainingMiles: Double
    let isOnRoute: Bool
    let hasArrived: Bool

    init(route: NavigationRoute, location: CLLocationCoordinate2D?, authorization: CLAuthorizationStatus) {
        guard let location, let position = Geographic.position(on: route.segments, near: location) else {
            maneuver = .location
            distanceToManeuver = nil
            instruction = authorization == .denied || authorization == .restricted ? "Location access is off" : "Waiting for your location"
            detail = authorization == .denied || authorization == .restricted
                ? "Enable RouteRisk location access in Settings to follow this route"
                : "Your position will appear here when available"
            nextManeuver = nil
            nextDistance = nil
            nextInstruction = nil
            remainingMinutes = route.minutes
            remainingMiles = route.miles
            isOnRoute = false
            hasArrived = false
            return
        }

        if position.distanceFromRoute > 180 {
            maneuver = .navigation
            distanceToManeuver = Self.distanceText(position.distanceFromRoute)
            instruction = "Return to the route"
            detail = "Approach the blue route, or tap reroute"
            let nextStep = route.instructions.first { step in
                guard let stepPosition = Geographic.position(on: route.segments, near: step.coordinate) else { return false }
                return stepPosition.distanceAlongRoute > position.distanceAlongRoute + 20
            }
            nextManeuver = nextStep.map { GuidanceManeuver.from($0.text) }
            nextDistance = nil
            nextInstruction = nextStep?.text
            remainingMinutes = route.minutes
            remainingMiles = route.miles
            isOnRoute = false
            hasArrived = false
            return
        }

        let remainingMeters = max(0, route.distanceMeters * (1 - position.progress))
        remainingMiles = remainingMeters / 1_609.344
        remainingMinutes = remainingMeters < 75 ? 0 : max(1, Int(ceil(route.expectedTravelTime * (1 - position.progress) / 60)))
        let distanceToDestination = Geographic.distance(from: location, to: route.segments.last?.end ?? location)

        if remainingMeters < 75 && distanceToDestination < 100 {
            maneuver = .arrival
            distanceToManeuver = nil
            instruction = "You've arrived"
            detail = nil
            nextManeuver = nil
            nextDistance = nil
            nextInstruction = nil
            isOnRoute = true
            hasArrived = true
        } else {
            isOnRoute = true
            hasArrived = false
            let upcoming = route.instructions.compactMap { step -> (RouteInstruction, CLLocationDistance)? in
                guard let stepPosition = Geographic.position(on: route.segments, near: step.coordinate),
                      stepPosition.distanceAlongRoute > position.distanceAlongRoute + 20 else { return nil }
                return (step, stepPosition.distanceAlongRoute - position.distanceAlongRoute)
            }.sorted { $0.1 < $1.1 }
            let next = upcoming.first
            let afterNext = upcoming.dropFirst().first
            instruction = next?.0.text ?? "Continue to \(route.name) destination"
            maneuver = next.map { GuidanceManeuver.from($0.0.text) } ?? .straight
            distanceToManeuver = next.map { $0.1 < 30 ? "Now" : "In \(Self.distanceText($0.1))" }
            detail = next == nil ? "Follow the highlighted route" : nil
            nextManeuver = afterNext.map { GuidanceManeuver.from($0.0.text) }
            nextDistance = afterNext.map {
                let distance = max(0, $0.1 - (next?.1 ?? 0))
                return distance < 30 ? "immediately" : Self.distanceText(distance)
            }
            nextInstruction = afterNext?.0.text
        }
    }

    private static func distanceText(_ meters: CLLocationDistance) -> String {
        if meters < 300 { return "\(Int((meters * 3.28084 / 50).rounded() * 50)) ft" }
        return String(format: "%.1f mi", meters / 1_609.344)
    }
}

private enum GuidanceManeuver {
    case straight, left, right, slightLeft, slightRight, sharpLeft, sharpRight
    case uTurn, roundabout, merge, exit, navigation, location, arrival

    var symbolName: String {
        switch self {
        case .straight: "arrow.up"
        case .left, .sharpLeft: "arrow.turn.up.left"
        case .right, .sharpRight: "arrow.turn.up.right"
        case .slightLeft: "arrow.up.left"
        case .slightRight: "arrow.up.right"
        case .uTurn: "arrow.uturn.left"
        case .roundabout: "arrow.clockwise"
        case .merge: "arrow.merge"
        case .exit: "arrow.triangle.branch"
        case .navigation: "location.north.fill"
        case .location: "location"
        case .arrival: "mappin"
        }
    }

    static func from(_ instruction: String) -> Self {
        let text = instruction.lowercased()
        if text.contains("u-turn") || text.contains("u turn") { return .uTurn }
        if text.contains("roundabout") || text.contains("traffic circle") { return .roundabout }
        if text.contains("sharp left") { return .sharpLeft }
        if text.contains("sharp right") { return .sharpRight }
        if text.contains("slight left") || text.contains("keep left") || text.contains("bear left") { return .slightLeft }
        if text.contains("slight right") || text.contains("keep right") || text.contains("bear right") { return .slightRight }
        if text.contains("left") { return .left }
        if text.contains("right") { return .right }
        if text.contains("merge") { return .merge }
        if text.contains("exit") { return .exit }
        return .straight
    }
}

private struct RouteEndpointPanel: View {
    let originName: String
    let destinationName: String
    let changeOrigin: () -> Void
    let changeDestination: () -> Void
    let showSettings: () -> Void
    let swapEndpoints: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                endpointButton(name: originName, isOrigin: true, action: changeOrigin)
                Button(action: showSettings) {
                    MaterialIcon(name: "MuiMoreHoriz", size: 25)
                        .foregroundStyle(RouteRiskTheme.subduedText)
                        .frame(width: 44, height: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)
                .padding(.leading, 56)

            HStack(spacing: 0) {
                endpointButton(name: destinationName, isOrigin: false, action: changeDestination)
                Button(action: swapEndpoints) {
                    MaterialIcon(name: "MuiSwapVert", size: 24)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 44, height: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap starting point and destination")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(RouteRiskTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .leading) {
            VStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle().fill(.white.opacity(0.42)).frame(width: 3, height: 3)
                }
            }
            .frame(width: 28)
            .offset(x: 14)
            .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.20), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }

    private func endpointButton(name: String, isOrigin: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Group {
                    if isOrigin {
                        Circle()
                            .fill(RouteRiskTheme.action)
                            .frame(width: 11, height: 11)
                            .padding(5)
                            .background(RouteRiskTheme.action.opacity(0.18), in: Circle())
                    } else {
                        MaterialIcon(name: "MuiPlaceOutlined", size: 23)
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.66))
                    }
                }
                .frame(width: 28)

                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isOrigin ? Color.white.opacity(0.80) : .white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOrigin ? "Change starting location, \(name)" : "Change destination, \(name)")
    }
}

struct MaterialIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
