import Foundation

struct RiskScoringConfiguration {
    var crashSearchRadiusMeters: Double = 170
    var severityWeights: [CrashSeverity: Double] = [.propertyDamage: 1, .injury: 2.3, .seriousInjury: 5.5, .fatal: 9]
    var recencyHorizonDays: Double = 730
    var nighttimeMultiplier: Double = 1.55
    var pedestrianMultiplier: Double = 1.45
    var cyclistMultiplier: Double = 1.35
    var highSpeedMultiplier: Double = 1.18
    var scoreModerateThreshold: Double = 0.5
    var scoreElevatedThreshold: Double = 2.2
    var scoreHighThreshold: Double = 4.0
}

struct RiskScoringService {
    let provider: any CrashDataProvider
    let configuration: RiskScoringConfiguration

    init(provider: any CrashDataProvider = SampleCrashDataProvider(), configuration: RiskScoringConfiguration = .init()) {
        self.provider = provider
        self.configuration = configuration
    }

    func analyze(_ route: NavigationRoute, departure: DeparturePeriod, mode: TravelMode) async -> NavigationRoute {
        let segmentExposures = await route.segments.asyncMap { segment in
            let records = await provider.crashes(near: segment, radius: configuration.crashSearchRadiusMeters)
            return exposure(for: segment, records: records, departure: departure, mode: mode)
        }
        let miles = max(route.miles, 0.01)
        let weighted = segmentExposures.reduce(0) { $0 + $1.score * ($1.segment.distanceMeters / 1_609.344) }
        let severe = segmentExposures.reduce(0) { $0 + Double($1.severeCrashCount) * ($1.segment.distanceMeters / 1_609.344) }
        let uniqueIntersections = Set(segmentExposures.flatMap { exposure in
            exposure.crashCount > 0 ? [exposure.segment.id] : []
        }).count
        let elevatedMiles = segmentExposures.filter { $0.level >= .elevated }.reduce(0) { $0 + $1.segment.distanceMeters / 1_609.344 }
        let nightMiles = departure == .nighttime ? segmentExposures.filter(\.nighttimeSensitive).reduce(0) { $0 + $1.segment.distanceMeters / 1_609.344 } : 0
        let allCrashes = await provider.allCrashes()
        let nearby = segmentExposures.flatMap { item in
            allCrashes.filter { Geographic.pointToSegmentDistance(point: $0.coordinate, start: item.segment.start, end: item.segment.end) <= configuration.crashSearchRadiusMeters }
        }
        let exposure = RouteExposure(
            score: weighted / miles, level: level(for: weighted / miles), severeCrashExposure: severe / miles,
            intersectionCount: uniqueIntersections, elevatedMiles: elevatedMiles, nighttimeAdjustmentMiles: nightMiles,
            pedestrianExposure: Double(nearby.filter(\.pedestrianInvolved).count) / miles,
            cyclistExposure: Double(nearby.filter(\.cyclistInvolved).count) / miles, segments: segmentExposures
        )
        var analysed = route
        analysed.exposure = exposure
        return analysed
    }

    func rank(_ routes: [NavigationRoute], preference: Double) -> [RankedRoute] {
        guard let fastest = routes.map(\.expectedTravelTime).min(), let leastExposure = routes.map(\.exposure.score).min() else { return [] }
        let slowest = routes.map(\.expectedTravelTime).max() ?? fastest
        let highestExposure = routes.map(\.exposure.score).max() ?? leastExposure
        let results = routes.map { route -> (NavigationRoute, Double) in
            let time = normalized(route.expectedTravelTime, low: fastest, high: slowest)
            let risk = normalized(route.exposure.score, low: leastExposure, high: highestExposure)
            return (route, (1 - preference) * time + preference * risk)
        }.sorted { $0.1 < $1.1 }
        return results.enumerated().map { RankedRoute(route: $0.element.0, rank: $0.offset + 1, preferenceCost: $0.element.1) }
    }

    private func exposure(for segment: GeographicSegment, records: [CrashRecord], departure: DeparturePeriod, mode: TravelMode) -> SegmentExposure {
        let score = records.reduce(0.0) { partial, record in
            let proximity = max(0.2, 1 - Geographic.pointToSegmentDistance(point: record.coordinate, start: segment.start, end: segment.end) / configuration.crashSearchRadiusMeters)
            let days = max(0, Date().timeIntervalSince(record.timestamp) / 86_400)
            let recency = max(0.25, 1 - days / configuration.recencyHorizonDays)
            var context = record.speedLimit >= 50 ? configuration.highSpeedMultiplier : 1.0
            if departure == .nighttime && record.lightingCondition != .daylight { context *= configuration.nighttimeMultiplier }
            if mode == .walking && record.pedestrianInvolved { context *= configuration.pedestrianMultiplier }
            if mode == .cycling && record.cyclistInvolved { context *= configuration.cyclistMultiplier }
            return partial + (configuration.severityWeights[record.severity] ?? 1) * proximity * recency * context
        }
        return SegmentExposure(id: segment.id, segment: segment, score: score, crashCount: records.count,
            severeCrashCount: records.filter { $0.severity >= .seriousInjury }.count,
            nighttimeSensitive: records.contains { $0.lightingCondition != .daylight }, level: level(for: score))
    }

    private func level(for score: Double) -> ExposureLevel {
        if score >= configuration.scoreHighThreshold { return .high }
        if score >= configuration.scoreElevatedThreshold { return .elevated }
        if score >= configuration.scoreModerateThreshold { return .moderate }
        return .lower
    }

    private func normalized(_ value: Double, low: Double, high: Double) -> Double {
        guard high > low else { return 0 }
        return (value - low) / (high - low)
    }
}

extension Array {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values: [T] = []
        for element in self { values.append(await transform(element)) }
        return values
    }
}
