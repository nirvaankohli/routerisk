import MapKit
import SwiftUI

struct SearchDock: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 12) {
                Image("RouteRiskLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                Text("Search here")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                Spacer(minLength: 0)
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RouteRiskTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(RouteRiskTheme.elevatedSurface, in: Circle())
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(RouteRiskTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.28), radius: 16, y: 7)
        .accessibilityLabel("Search for a destination")
        .accessibilityHint("Opens destination search")
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
    @State private var query = ""
    @FocusState private var searchIsFocused: Bool
    @State private var isResolving = false
    @State private var placeToSave: SavedPlace?
    let onDestinationSelected: () -> Void

    private enum SavedPlace { case home, work }

    init(onDestinationSelected: @escaping () -> Void = {}) {
        self.onDestinationSelected = onDestinationSelected
    }

    private var recents: [String] {
        storedRecents.split(separator: "\u{1F}").map(String.init)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 18)

            quickPlaces
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

            Divider().overlay(Color.primary.opacity(0.12))

            Group {
                if query.isEmpty {
                    recentContent
                } else {
                    suggestionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RouteRiskTheme.canvas)
        }
        .background(RouteRiskTheme.canvas.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(180))
            searchIsFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 38, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            TextField(searchPlaceholder, text: $query)
                .font(.title3)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .focused($searchIsFocused)
                .onSubmit { resolve(query: query) }
                .onChange(of: query) { _, value in
                    if value.count > 1 { search.update(query: value) }
                }

            if !query.isEmpty {
                Button { query = ""; search.update(query: "") } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            } else {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(RouteRiskTheme.subduedText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 58)
        .background(RouteRiskTheme.elevatedSurface, in: Capsule())
        .overlay {
            Capsule().stroke(searchIsFocused ? RouteRiskTheme.action.opacity(0.82) : .clear, lineWidth: 2)
        }
    }

    private var quickPlaces: some View {
        HStack(spacing: 22) {
            quickPlace(.home, symbol: "house", title: "Home", subtitle: homeName.isEmpty ? "Set location" : homeName)
            quickPlace(.work, symbol: "briefcase", title: "Work", subtitle: workName.isEmpty ? "Set location" : workName)
            quickPlace(nil, symbol: "plus", title: "Add", subtitle: "Saved place")
            Spacer(minLength: 0)
        }
    }

    private func quickPlace(_ savedPlace: SavedPlace?, symbol: String, title: String, subtitle: String) -> some View {
        Button {
            if let savedPlace, let destination = savedDestination(for: savedPlace) {
                completeRoute(to: destination.coordinate, title: destination.name)
            } else {
                placeToSave = savedPlace
                query = ""
                search.update(query: "")
                searchIsFocused = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(RouteRiskTheme.action.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(RouteRiskTheme.subduedText).lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(savedPlace == nil ? "Search for another saved place" : "Sets or routes to \(title.lowercased())")
    }

    @ViewBuilder private var recentContent: some View {
        if recents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent").font(.headline)
                Text("Places you search for will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent").font(.headline)
                    Spacer()
                    Button("Clear") { storedRecents = "" }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                ForEach(recents, id: \.self) { place in
                    Button { resolve(query: place) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.body)
                                .frame(width: 34, height: 34)
                                .background(Color.primary.opacity(0.11), in: Circle())
                            Text(place).font(.body).foregroundStyle(.primary).lineLimit(1)
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
            completeRoute(to: result.coordinate, title: result.title)
        }
    }

    private func resolve(query: String) {
        guard !query.isEmpty else { return }
        Task {
            isResolving = true
            guard let result = try? await search.resolve(query: query) else { isResolving = false; return }
            completeRoute(to: result.coordinate, title: result.title)
        }
    }

    private func completeRoute(to coordinate: CLLocationCoordinate2D, title: String) {
        if let placeToSave {
            save(title: title, coordinate: coordinate, as: placeToSave)
            self.placeToSave = nil
        }
        var values = recents.filter { $0.caseInsensitiveCompare(title) != .orderedSame }
        values.insert(title, at: 0)
        storedRecents = values.prefix(5).joined(separator: "\u{1F}")
        onDestinationSelected()
        dismiss()
        Task { await viewModel.routeTo(destination: coordinate, name: title, origin: locationService.currentLocation) }
    }

    private var searchPlaceholder: String {
        switch placeToSave {
        case .home: return "Search for your home"
        case .work: return "Search for your work"
        case .none: return "Search here"
        }
    }

    private func savedDestination(for place: SavedPlace) -> (name: String, coordinate: CLLocationCoordinate2D)? {
        switch place {
        case .home:
            guard !homeName.isEmpty else { return nil }
            return (homeName, CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude))
        case .work:
            guard !workName.isEmpty else { return nil }
            return (workName, CLLocationCoordinate2D(latitude: workLatitude, longitude: workLongitude))
        }
    }

    private func save(title: String, coordinate: CLLocationCoordinate2D, as place: SavedPlace) {
        switch place {
        case .home:
            homeName = title
            homeLatitude = coordinate.latitude
            homeLongitude = coordinate.longitude
        case .work:
            workName = title
            workLatitude = coordinate.latitude
            workLongitude = coordinate.longitude
        }
    }
}
