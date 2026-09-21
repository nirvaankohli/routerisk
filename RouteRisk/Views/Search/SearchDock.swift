import MapKit
import SwiftUI

struct SearchDock: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var search = DestinationSearchService()
    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Where are you going?", text: $query)
                    .textInputAutocapitalization(.words)
                    .focused($isFocused)
                    .onChange(of: query) { _, value in
                        if value.count > 1 { search.update(query: value) }
                    }
                if !query.isEmpty {
                    Button { query = ""; search.update(query: "") } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .accessibilityLabel("Clear destination")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)

            if isFocused && !search.suggestions.isEmpty {
                Divider()
                ForEach(search.suggestions.prefix(5)) { suggestion in
                    Button {
                        Task {
                            guard let result = try? await search.resolve(suggestion) else { return }
                            query = result.title
                            isFocused = false
                            await viewModel.routeTo(destination: result.coordinate, name: result.title, origin: locationService.currentLocation)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.blue).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title).foregroundStyle(.primary).lineLimit(1)
                                if !suggestion.subtitle.isEmpty { Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }
}
