import MapKit
import SwiftUI

struct SearchDock: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image("SearchDockLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                Text("Search places")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search for a destination")
        .accessibilityHint("Opens destination search")
    }
}

enum SavedPlaceKind {
    case home, work, school, custom
}

struct RecentPlace: Codable, Identifiable {
    let name: String
    let subtitle: String

    var id: String { name.lowercased() }

    static func decode(_ stored: String) -> [RecentPlace] {
        if let data = stored.data(using: .utf8),
           let places = try? JSONDecoder().decode([RecentPlace].self, from: data) {
            return places
        }
        return stored.split(separator: "\u{1F}").map { RecentPlace(name: String($0), subtitle: "") }
    }

    static func encode(_ places: [RecentPlace]) -> String {
        guard let data = try? JSONEncoder().encode(places),
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }
}

private struct SavedCustomPlace: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceShortcutRow: View {
    let homeDetail: String
    let workDetail: String
    let schoolDetail: String
    let onHome: () -> Void
    let onWork: () -> Void
    let onSchool: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            shortcut("Home", detail: homeDetail, icon: "MuiHome", style: .home, action: onHome)
            shortcut("Work", detail: workDetail, icon: "MuiWork", style: .work, action: onWork)
            shortcut("School", detail: schoolDetail, icon: "MuiSchool", style: .school, action: onSchool)
            shortcut("Add", detail: "Save place", icon: "MuiAdd", style: .add, action: onAdd)
        }
    }

    private func shortcut(_ title: String, detail: String, icon: String, style: PlaceShortcutStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                MaterialIcon(name: icon, size: 30)
                    .foregroundStyle(style.iconColor)
                    .frame(width: 68, height: 68)
                    .background(style.background, in: Circle())
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RouteRiskTheme.subduedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlaceShortcutButtonStyle())
        .accessibilityLabel("\(title), \(detail)")
    }
}

private enum PlaceShortcutStyle {
    case home, work, school, add

    var iconColor: Color {
        switch self {
        case .add: Color(red: 0.37, green: 0.76, blue: 1.0)
        case .home, .work, .school: .white
        }
    }

    var background: LinearGradient {
        let colors: [Color]
        switch self {
        case .home:
            colors = [Color(red: 0.23, green: 0.82, blue: 0.94), Color(red: 0.02, green: 0.64, blue: 0.78)]
        case .work:
            colors = [Color(red: 0.36, green: 0.67, blue: 1.0), Color(red: 0.08, green: 0.43, blue: 0.91)]
        case .school:
            colors = [Color(red: 0.99, green: 0.51, blue: 0.58), Color(red: 0.88, green: 0.25, blue: 0.43)]
        case .add:
            colors = [Color(red: 0.13, green: 0.28, blue: 0.36), Color(red: 0.09, green: 0.22, blue: 0.29)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct PlaceShortcutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct DestinationSearchView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = DestinationSearchService()
    @AppStorage("routeRisk.recentDestinations") private var storedRecents = ""
    @AppStorage("routeRisk.homeName") private var homeName = ""
    @AppStorage("routeRisk.homeLatitude") private var homeLatitude = 0.0
    @AppStorage("routeRisk.homeLongitude") private var homeLongitude = 0.0
    @AppStorage("routeRisk.workName") private var workName = ""
    @AppStorage("routeRisk.workLatitude") private var workLatitude = 0.0
    @AppStorage("routeRisk.workLongitude") private var workLongitude = 0.0
    @AppStorage("routeRisk.schoolName") private var schoolName = ""
    @AppStorage("routeRisk.schoolLatitude") private var schoolLatitude = 0.0
    @AppStorage("routeRisk.schoolLongitude") private var schoolLongitude = 0.0
    @AppStorage("routeRisk.savedPlaces") private var savedPlacesData = Data()
    // Keep a place saved before the Marked shortcut became School.
    @AppStorage("routeRisk.markedName") private var markedName = ""
    @AppStorage("routeRisk.markedLatitude") private var markedLatitude = 0.0
    @AppStorage("routeRisk.markedLongitude") private var markedLongitude = 0.0
    @State private var query = ""
    @FocusState private var searchIsFocused: Bool
    @State private var isResolving = false
    @State private var placeToSave: SavedPlaceKind?
    @State private var addingPlaceOnly = false
    @State private var awaitingCurrentLocation = false
    @State private var locationMessage: String?
    let onStopSelected: (TripStop) async -> Void
    let onDestinationSelected: () -> Void
    let endpoint: RouteEndpoint
    let savesWithoutRouting: Bool
    let focusesOnAppear: Bool
    let initialQuery: String

    init(endpoint: RouteEndpoint = .destination, saveTarget: SavedPlaceKind? = nil, savesWithoutRouting: Bool = false, focusesOnAppear: Bool = true, initialQuery: String = "", onStopSelected: @escaping (TripStop) async -> Void = { _ in }, onDestinationSelected: @escaping () -> Void = {}) {
        self.endpoint = endpoint
        self.savesWithoutRouting = savesWithoutRouting
        self.focusesOnAppear = focusesOnAppear
        self.initialQuery = initialQuery
        self.onStopSelected = onStopSelected
        self.onDestinationSelected = onDestinationSelected
        _query = State(initialValue: initialQuery)
        _placeToSave = State(initialValue: saveTarget)
    }

    private var recents: [RecentPlace] {
        RecentPlace.decode(storedRecents)
    }

    private var savedPlaces: [SavedCustomPlace] {
        (try? JSONDecoder().decode([SavedCustomPlace].self, from: savedPlacesData)) ?? []
    }

    private var visibleRecents: [RecentPlace] {
        recents
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                searchBar
                if endpoint == .origin && query.isEmpty {
                    Button(action: useCurrentLocation) {
                        Label(awaitingCurrentLocation ? "Finding your location…" : "Use my current location", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RouteRiskTheme.action)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(awaitingCurrentLocation)
                    if let locationMessage {
                        Text(locationMessage).font(.footnote).foregroundStyle(.orange)
                    }
                }
                if query.isEmpty && !savesWithoutRouting {
                    Text("Places")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    quickPlaces
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RouteRiskTheme.surface)

            ScrollView {
                if query.isEmpty {
                    if !savesWithoutRouting && !addingPlaceOnly { savedPlacesContent }
                    recentContent
                }
                else { suggestionContent }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RouteRiskTheme.surface)
        }
        .background(RouteRiskTheme.surface.ignoresSafeArea())
        .task {
            migrateMarkedPlace()
            if !initialQuery.isEmpty { search.update(query: initialQuery) }
            guard focusesOnAppear else { return }
            try? await Task.sleep(for: .milliseconds(180))
            searchIsFocused = true
        }
        .onReceive(locationService.$currentLocation) { coordinate in
            guard awaitingCurrentLocation, let coordinate else { return }
            awaitingCurrentLocation = false
            Task { await finishUsingCurrentLocation(coordinate) }
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            if status == .denied || status == .restricted {
                awaitingCurrentLocation = false
                locationMessage = "Allow RouteRisk to use your location in iPhone Settings."
            }
        }
    }

    private func useCurrentLocation() {
        locationMessage = nil
        if let coordinate = locationService.currentLocation {
            Task { await finishUsingCurrentLocation(coordinate) }
        } else if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            locationMessage = "Allow RouteRisk to use your location in iPhone Settings."
        } else {
            awaitingCurrentLocation = true
            locationService.requestLocation()
        }
    }

    private func finishUsingCurrentLocation(_ coordinate: CLLocationCoordinate2D) async {
        await viewModel.routeTo(destination: viewModel.destinationCoordinate, name: viewModel.destinationName, origin: coordinate, originName: "Your location")
        onDestinationSelected()
        dismiss()
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 52)
                    .background(RouteRiskTheme.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RouteRiskTheme.action)
                TextField(searchPlaceholder, text: $query)
                    .font(.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .focused($searchIsFocused)
                    .onSubmit { resolve(query: query) }
                    .onChange(of: query) { _, value in search.update(query: value) }

                if !query.isEmpty {
                    Button { query = ""; search.update(query: "") } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(RouteRiskTheme.elevatedSurface, in: Capsule())
            .overlay {
                Capsule().stroke(searchIsFocused ? RouteRiskTheme.action.opacity(0.8) : .clear, lineWidth: 1.5)
            }
        }
    }

    private var quickPlaces: some View {
        PlaceShortcutRow(
            homeDetail: homeName.isEmpty ? "Not set" : homeName,
            workDetail: workName.isEmpty ? "Not set" : workName,
            schoolDetail: schoolName.isEmpty ? "Not set" : schoolName,
            onHome: { quickPlace(.home) },
            onWork: { quickPlace(.work) },
            onSchool: { quickPlace(.school) },
            onAdd: {
                placeToSave = .custom
                addingPlaceOnly = true
                query = ""
                search.update(query: "")
                searchIsFocused = true
            }
        )
    }

    private func quickPlace(_ savedPlace: SavedPlaceKind) {
        if let destination = savedDestination(for: savedPlace) {
            Task { await completeRoute(to: destination.coordinate, title: destination.name) }
        } else {
            placeToSave = savedPlace
            query = ""
            search.update(query: "")
            searchIsFocused = true
        }
    }

    @ViewBuilder private var savedPlacesContent: some View {
        if !savedPlaces.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Saved places")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                ForEach(savedPlaces) { place in
                    HStack(spacing: 0) {
                        Button {
                            Task { await completeRoute(to: place.coordinate, title: place.name) }
                        } label: {
                            HStack(spacing: 16) {
                                MaterialIcon(name: "MuiPlaceOutlined", size: 22)
                                    .foregroundStyle(RouteRiskTheme.action)
                                    .frame(width: 36, height: 36)
                                    .background(RouteRiskTheme.action.opacity(0.15), in: Circle())
                                Text(place.name)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button("Remove place", role: .destructive) { removeSavedPlace(place.id) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(RouteRiskTheme.subduedText)
                                .frame(width: 52, height: 52)
                        }
                        .accessibilityLabel("More options for \(place.name)")
                    }
                    Divider().padding(.leading, 76)
                }
            }
        }
    }

    @ViewBuilder private var recentContent: some View {
        if visibleRecents.isEmpty && savedPlaces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent").font(.headline)
                Text("Places you search for will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
        } else if !visibleRecents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent").font(.headline)
                    Spacer()
                    Button("Clear") { storedRecents = "" }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                ForEach(visibleRecents) { place in
                    Button { resolve(query: place.name) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.body)
                                .foregroundStyle(RouteRiskTheme.action)
                                .frame(width: 34, height: 34)
                                .background(RouteRiskTheme.action.opacity(0.15), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).font(.body).foregroundStyle(.primary).lineLimit(1)
                                if !place.subtitle.isEmpty {
                                    Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 82)
                }
            }
        }
    }

    @ViewBuilder private var suggestionContent: some View {
        if isResolving {
            ProgressView("Finding route…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        } else if search.suggestions.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, 48)
        } else {
            VStack(spacing: 0) {
                ForEach(search.suggestions.prefix(7)) { suggestion in
                    Button { resolve(suggestion) } label: {
                        HStack(alignment: .top, spacing: 15) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.body)
                                .foregroundStyle(RouteRiskTheme.action)
                                .frame(width: 34, height: 34)
                                .background(RouteRiskTheme.action.opacity(0.16), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 79)
                }
            }
            .padding(.top, 10)
        }
    }

    private func resolve(_ suggestion: SearchSuggestion) {
        Task {
            isResolving = true
            guard let result = try? await search.resolve(suggestion) else { isResolving = false; return }
            await completeRoute(to: result.coordinate, title: result.title, subtitle: suggestion.subtitle)
        }
    }

    private func resolve(query: String) {
        guard !query.isEmpty else { return }
        Task {
            isResolving = true
            guard let result = try? await search.resolve(query: query) else { isResolving = false; return }
            await completeRoute(to: result.coordinate, title: result.title)
        }
    }

    private func completeRoute(to coordinate: CLLocationCoordinate2D, title: String, subtitle: String = "") async {
        if let placeToSave {
            save(title: title, coordinate: coordinate, as: placeToSave)
            self.placeToSave = nil
        }
        if savesWithoutRouting || addingPlaceOnly {
            dismiss()
            return
        }
        let previousSubtitle = recents.first { $0.name.caseInsensitiveCompare(title) == .orderedSame }?.subtitle ?? ""
        var values = recents.filter { $0.name.caseInsensitiveCompare(title) != .orderedSame }
        values.insert(RecentPlace(name: title, subtitle: subtitle.isEmpty ? previousSubtitle : subtitle), at: 0)
        storedRecents = RecentPlace.encode(Array(values.prefix(5)))
        switch endpoint {
        case .destination:
            await viewModel.routeTo(destination: coordinate, name: title, origin: viewModel.originCoordinate, originName: viewModel.originName)
        case .origin:
            await viewModel.routeTo(destination: viewModel.destinationCoordinate, name: viewModel.destinationName, origin: coordinate, originName: title)
        case .stop:
            await onStopSelected(TripStop(name: title, coordinate: coordinate))
        }
        if endpoint != .stop { onDestinationSelected() }
        dismiss()
    }

    private var searchPlaceholder: String {
        switch placeToSave {
        case .home: return "Search for your home"
        case .work: return "Search for your work"
        case .school: return "Search for your school"
        case .custom: return "Search for a place to save"
        case .none:
            if endpoint == .origin { return "Search starting point" }
            if endpoint == .stop { return "Search for a stop" }
            return "Search places"
        }
    }

    private func savedDestination(for place: SavedPlaceKind) -> (name: String, coordinate: CLLocationCoordinate2D)? {
        switch place {
        case .home:
            guard !homeName.isEmpty else { return nil }
            return (homeName, CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude))
        case .work:
            guard !workName.isEmpty else { return nil }
            return (workName, CLLocationCoordinate2D(latitude: workLatitude, longitude: workLongitude))
        case .school:
            guard !schoolName.isEmpty else { return nil }
            return (schoolName, CLLocationCoordinate2D(latitude: schoolLatitude, longitude: schoolLongitude))
        case .custom:
            return nil
        }
    }

    private func save(title: String, coordinate: CLLocationCoordinate2D, as place: SavedPlaceKind) {
        switch place {
        case .home:
            homeName = title
            homeLatitude = coordinate.latitude
            homeLongitude = coordinate.longitude
        case .work:
            workName = title
            workLatitude = coordinate.latitude
            workLongitude = coordinate.longitude
        case .school:
            schoolName = title
            schoolLatitude = coordinate.latitude
            schoolLongitude = coordinate.longitude
        case .custom:
            var places = savedPlaces
            guard !places.contains(where: { $0.name.caseInsensitiveCompare(title) == .orderedSame }) else { return }
            places.append(SavedCustomPlace(name: title, latitude: coordinate.latitude, longitude: coordinate.longitude))
            storeSavedPlaces(places)
        }
    }

    private func removeSavedPlace(_ id: UUID) {
        storeSavedPlaces(savedPlaces.filter { $0.id != id })
    }

    private func storeSavedPlaces(_ places: [SavedCustomPlace]) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        savedPlacesData = data
    }

    private func migrateMarkedPlace() {
        guard !markedName.isEmpty else { return }
        var places = savedPlaces
        if !places.contains(where: { $0.name.caseInsensitiveCompare(markedName) == .orderedSame }) {
            places.append(SavedCustomPlace(name: markedName, latitude: markedLatitude, longitude: markedLongitude))
            storeSavedPlaces(places)
        }
        markedName = ""
    }
}
