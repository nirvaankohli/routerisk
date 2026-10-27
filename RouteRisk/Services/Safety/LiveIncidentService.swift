import CoreLocation
import Foundation

struct LiveRoadIncident: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let reportedAt: Date?
}

struct RouteIncidentAlert {
    let incident: LiveRoadIncident
    let metersAhead: CLLocationDistance
}

enum RouteIncidentMatcher {
    static func avoids(_ incidents: [CLLocationCoordinate2D], on route: NavigationRoute) -> Bool {
        incidents.allSatisfy { incident in
            guard let position = Geographic.position(on: route.segments, near: incident) else { return false }
            return position.distanceFromRoute > 300
        }
    }

    static func ahead(_ incidents: [LiveRoadIncident], on route: NavigationRoute, from location: CLLocationCoordinate2D) -> [RouteIncidentAlert] {
        guard let current = Geographic.position(on: route.segments, near: location),
              current.distanceFromRoute <= 180 else { return [] }

        return incidents.compactMap { incident in
            guard let position = Geographic.position(on: route.segments, near: incident.coordinate),
                  position.distanceFromRoute <= 300 else { return nil }
            let metersAhead = position.distanceAlongRoute - current.distanceAlongRoute
            guard (200...8_000).contains(metersAhead) else { return nil }
            return RouteIncidentAlert(incident: incident, metersAhead: metersAhead)
        }
        .sorted { $0.metersAhead < $1.metersAhead }
    }
}

struct NJ511IncidentService {
    static let feedURL = URL(string: "https://www.511nj.org/RSS511Service/RSS511Service.svc/rest/rss/RSSActiveIncidents")!

    func fetch() async throws -> [LiveRoadIncident] {
        var request = URLRequest(url: Self.feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        request.setValue("RouteRisk/1.0 (active-trip incident alerts)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try NJ511IncidentParser.parse(data)
    }
}

enum NJ511IncidentParser {
    static func parse(_ data: Data) throws -> [LiveRoadIncident] {
        let delegate = RSSDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return delegate.incidents
    }
}

private final class RSSDelegate: NSObject, XMLParserDelegate {
    private struct Item {
        var title = ""
        var point = ""
        var pubDate = ""
    }

    private var item: Item?
    private var activeField: String?
    private var fieldText = ""
    private(set) var incidents: [LiveRoadIncident] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" { item = Item() }
        guard item != nil else { return }
        let field = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if ["title", "point", "pubDate"].contains(field) {
            activeField = field
            fieldText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeField != nil { fieldText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var item else { return }
        let field = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if field == activeField {
            let value = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
            switch field {
            case "title": item.title = value
            case "point": item.point = value
            case "pubDate": item.pubDate = value
            default: break
            }
            self.item = item
            activeField = nil
        }
        if elementName == "item" {
            append(item)
            self.item = nil
        }
    }

    private func append(_ item: Item) {
        let title = item.title.lowercased()
        guard title.contains("crash") || title.contains("collision") || title.contains("accident") else { return }
        let numbers = item.point.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        guard numbers.count == 2, (-90...90).contains(numbers[0]), (-180...180).contains(numbers[1]) else { return }
        let coordinate = CLLocationCoordinate2D(latitude: numbers[0], longitude: numbers[1])
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let road = title.split(separator: ":", maxSplits: 1).first.map(String.init) ?? title
        let id = "\(road.trimmingCharacters(in: .whitespacesAndNewlines))|\(String(format: "%.4f,%.4f", numbers[0], numbers[1]))"
        incidents.append(LiveRoadIncident(id: id, title: item.title, coordinate: coordinate, reportedAt: dateFormatter.date(from: item.pubDate)))
    }
}
