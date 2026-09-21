import SwiftUI

struct RouteDecisionCard: View {
    let rankedRoute: RankedRoute
    let isSelected: Bool
    let fastestMinutes: Int
    let onSelect: () -> Void

    private var route: NavigationRoute { rankedRoute.route }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.kind.title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(isSelected ? .blue : .secondary)
                        Text("\(route.minutes) min").font(.title2.monospacedDigit().weight(.bold)).foregroundStyle(.primary)
                    }
                    Spacer()
                    if rankedRoute.rank == 1 { Text("RECOMMENDED").font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 5).background(.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue) }
                }
                Text("\(route.miles, specifier: "%.1f") mi · \(route.name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                ExposureBadge(level: route.exposure.level, compact: true)
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
            }
            .padding(15)
            .frame(width: 212, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.09) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Select \(route.kind.title) route")
    }

    private var summary: String {
        let added = max(0, route.minutes - fastestMinutes)
        if route.kind == .fastest { return "\(route.exposure.intersectionCount) high-crash intersections nearby" }
        if added == 0 { return "Lower severe-crash exposure" }
        return "Avoids elevated exposure, adds \(added) min"
    }
}
