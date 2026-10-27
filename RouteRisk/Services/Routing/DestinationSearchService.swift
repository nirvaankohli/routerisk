import Foundation
import MapKit

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

@MainActor
final class DestinationSearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [SearchSuggestion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func update(query: String) {
        suggestions = []
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.map(SearchSuggestion.init)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { suggestions = [] }

    func resolve(_ suggestion: SearchSuggestion) async throws -> (title: String, coordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw CocoaError(.fileNoSuchFile) }
        return (item.name ?? suggestion.title, item.placemark.coordinate)
    }

    func resolve(query: String) async throws -> (title: String, coordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw CocoaError(.fileNoSuchFile) }
        return (item.name ?? query, item.placemark.coordinate)
    }

    func subtitle(query: String) async throws -> String {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let place = response.mapItems.first?.placemark else { throw CocoaError(.fileNoSuchFile) }
        let location = [place.locality, place.administrativeArea].compactMap { $0 }
        return location.isEmpty ? (place.title ?? "") : location.joined(separator: ", ")
    }
}
