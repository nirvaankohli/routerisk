import MapKit
import SwiftUI

struct RouteComparisonSheet: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Binding var showingDetails: Bool
    @State private var isExpanded: Bool
    @GestureState private var dragTranslation: CGFloat = 0
    let onCollapseToHome: () -> Void

    init(showingDetails: Binding<Bool>, startsExpanded: Bool = false, onCollapseToHome: @escaping () -> Void = {}) {
        _showingDetails = showingDetails
        _isExpanded = State(initialValue: startsExpanded)
        self.onCollapseToHome = onCollapseToHome
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.24)) { isExpanded.toggle() }
            } label: {
                Capsule().fill(.tertiary).frame(width: 38, height: 5)
                    .padding(.top, 10).padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse route options" : "Expand route options")

            if isExpanded {
                expandedContent
            } else {
                compactSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: isExpanded ? 575 : 118, alignment: .top)
        .safeAreaPadding(.bottom, 8)
        .background(RouteRiskTheme.surface.opacity(0.96))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: -4)
        .simultaneousGesture(sheetDragGesture)
        .animation(.easeOut(duration: 0.24), value: isExpanded)
        .accessibilityElement(children: .contain)
    }

    private var compactSummary: some View {
        Button {
            withAnimation(.easeOut(duration: 0.24)) { isExpanded = true }
        } label: {
            HStack(spacing: 12) {
                if let selected = viewModel.selectedRoute {
                    Image(systemName: selected.exposure.level.symbol)
                        .foregroundStyle(selected.exposure.level.color)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Route tradeoff").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text("\(selected.minutes) min · \(selected.kind.title) · \(selected.exposure.level.title) exposure")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Label("Route tradeoff", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to show all route options")
    }

    private var expandedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Route options").font(.headline)
                        Text(viewModel.destinationName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Label(viewModel.crashDataStatus.badgeTitle, systemImage: viewModel.crashDataStatus.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.crashDataStatus == .live ? RouteRiskTheme.accent : RouteRiskTheme.subduedText)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RouteRiskTheme.elevatedSurface, in: Capsule())
                }
                .padding(.horizontal, 20)

                if viewModel.isLoading {
                    ProgressView("Finding route alternatives…").padding(.horizontal, 20)
                } else if let message = viewModel.errorMessage {
                    Label(message, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                } else if !viewModel.rankedRoutes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(viewModel.rankedRoutes) { ranked in
                            routeRow(ranked)
                        }
                    }
                    .padding(.horizontal, 16)

                    preferenceControl

                    if let selected = viewModel.selectedRoute {
                        HStack(spacing: 10) {
                            Button { showingDetails = true } label: {
                                Label("Why this route?", systemImage: "info.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button(action: startNavigation) {
                                Label("Start", systemImage: "location.north.fill")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 104, height: 46)
                                    .background(RouteRiskTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(RouteRiskTheme.canvas)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens Apple Maps with this route")
                        }
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Selected route: \(selected.minutes) minutes")
                    }
                }
            }
            .padding(.bottom, 18)
        }
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                let end = value.predictedEndTranslation.height
                guard abs(end) > 36 else { return }
                withAnimation(.easeOut(duration: 0.24)) { isExpanded = end < 0 }
            }
    }

    private func routeRow(_ ranked: RankedRoute) -> some View {
        let route = ranked.route
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { viewModel.select(route) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedRouteID == route.id ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.selectedRouteID == route.id ? RouteRiskTheme.action : RouteRiskTheme.subduedText)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(route.kind.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        if ranked.rank == 1 {
                            Text(recommendationText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(RouteRiskTheme.accent)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(RouteRiskTheme.accent.opacity(0.13), in: Capsule())
                        }
                    }
                    Text("\(route.minutes) min · \(route.miles, specifier: "%.1f") mi · \(route.exposure.level.title) exposure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(routeExplanation(route))
                        .font(.caption)
                        .foregroundStyle(RouteRiskTheme.subduedText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: route.exposure.level.symbol)
                    .font(.body)
                    .foregroundStyle(route.exposure.level.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(viewModel.selectedRouteID == route.id ? RouteRiskTheme.action.opacity(0.13) : RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(viewModel.selectedRouteID == route.id ? RouteRiskTheme.action : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.kind.title), \(route.minutes) minutes, \(route.exposure.level.title) historical exposure")
    }

    private var preferenceControl: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Preference").font(.subheadline.weight(.semibold))
                Spacer()
                Text(preferenceText).font(.caption).foregroundStyle(.secondary)
            }
            RiskPreferenceControl(preference: $viewModel.riskPreference)
        }
        .padding(14)
        .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var recommendationText: String {
        switch viewModel.riskPreference {
        case ..<0.34: return "BEST FOR SPEED"
        case 0.67...: return "BEST FOR EXPOSURE"
        default: return "RECOMMENDED"
        }
    }

    private func routeExplanation(_ route: NavigationRoute) -> String {
        let fastest = viewModel.routes.map(\.minutes).min() ?? route.minutes
        let added = max(0, route.minutes - fastest)
        if route.kind == .fastest { return "Fastest available travel time" }
        if route.kind == .lowerExposure { return added > 0 ? "Lower historical exposure for \(added) extra min" : "Lowest historical exposure" }
        return "Balances time with historical exposure"
    }

    private func startNavigation() {
        let origin = MKMapItem(placemark: MKPlacemark(coordinate: viewModel.originCoordinate))
        origin.name = viewModel.originName
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: viewModel.destinationCoordinate))
        destination.name = viewModel.destinationName
        MKMapItem.openMaps(with: [origin, destination], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private var preferenceText: String {
        switch viewModel.riskPreference { case ..<0.34: return "Time-first"; case 0.67...: return "Exposure-first"; default: return "Balanced" }
    }

    private func explanationPreview(for route: NavigationRoute) -> String {
        let added = max(0, route.minutes - (viewModel.routes.map(\.minutes).min() ?? route.minutes))
        return added > 0 ? "Lower exposure for \(added) extra min" : "Fastest available option"
    }
}
