import Foundation
import SwiftUI

struct RouteDetailView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let route = viewModel.selectedRoute {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header(route)
                            explanation(route)
                            metrics(route)
                            if route.exposure.nighttimeAdjustmentMiles > 0 {
                                Label(String(format: "Nighttime history increased exposure along %.1f miles of this route.", route.exposure.nighttimeAdjustmentMiles), systemImage: "moon.stars.fill")
                                    .font(.subheadline).foregroundStyle(.secondary).padding(15).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            segments(route)
                            Text(route.isSampleData ? "Demo data uses a local, representative crash dataset. Historical exposure is not a prediction or guarantee of safety." : "Historical exposure is not a prediction or guarantee of safety.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }.padding(20)
                    }
                } else { ContentUnavailableView("No route selected", systemImage: "map") }
            }
            .navigationTitle("Route details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func header(_ route: NavigationRoute) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(route.kind.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.blue)
                Text("\(route.minutes) min").font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                Text(String(format: "%.1f mi via %@", route.miles, route.name)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            ExposureBadge(level: route.exposure.level)
        }
    }

    private func explanation(_ route: NavigationRoute) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Why this route?").font(.title3.weight(.bold))
            ForEach(reasons(route), id: \.self) { reason in Label(reason, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.primary) }
        }
        .padding(18).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metrics(_ route: NavigationRoute) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Historical indicators").font(.headline)
            metric("Severe-crash exposure", value: String(format: "%.1f relative", route.exposure.severeCrashExposure), symbol: "bolt.shield")
            metric("High-crash intersections", value: "\(route.exposure.intersectionCount)", symbol: "arrow.triangle.turn.up.right.diamond")
            metric("Elevated-exposure roadway", value: String(format: "%.1f mi", route.exposure.elevatedMiles), symbol: "point.topleft.down.curvedto.point.bottomright.up")
            metric("Pedestrian exposure", value: String(format: "%.1f relative", route.exposure.pedestrianExposure), symbol: "figure.walk")
        }
    }

    private func segments(_ route: NavigationRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Along this route").font(.headline)
            ForEach(route.exposure.segments) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.level.symbol).foregroundStyle(item.level.color).frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.segment.roadName).font(.subheadline.weight(.semibold))
                        Text("Historical exposure: \(item.level.title) · \(item.crashCount) crashes represented").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(.vertical, 4)
            }
        }
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        HStack { Image(systemName: symbol).foregroundStyle(.blue).frame(width: 22); Text(title).font(.subheadline); Spacer(); Text(value).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary) }
    }

    private func reasons(_ route: NavigationRoute) -> [String] {
        let fastest = viewModel.routes.min { $0.expectedTravelTime < $1.expectedTravelTime }
        let extra = max(0, route.minutes - (fastest?.minutes ?? route.minutes))
        var values = [String(format: "Uses %.1f miles of elevated-exposure roadway", route.exposure.elevatedMiles), "Includes \(route.exposure.intersectionCount) historically high-crash intersections"]
        if extra > 0 { values.append("Adds only \(extra) minutes compared with the fastest route") }
        if route.exposure.nighttimeAdjustmentMiles > 0 { values.append("Flags a segment with elevated nighttime crash history") }
        return values
    }
}
