import SwiftUI

struct RouteComparisonSheet: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Binding var showingDetails: Bool
    @State private var isExpanded = false
    @GestureState private var dragTranslation: CGFloat = 0

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
        .frame(height: isExpanded ? 520 : 112, alignment: .top)
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
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Route tradeoff").font(.headline)
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

                    if viewModel.isLoading { ProgressView("Analyzing historical crash exposure…").padding(.horizontal, 20) }
                    if let message = viewModel.errorMessage { Label(message, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20) }

                    if !viewModel.routes.isEmpty {
                        let fastest = viewModel.routes.map(\.minutes).min() ?? 0
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 11) {
                                ForEach(viewModel.rankedRoutes) { ranked in
                                    RouteDecisionCard(rankedRoute: ranked, isSelected: viewModel.selectedRouteID == ranked.route.id, fastestMinutes: fastest) {
                                        withAnimation(.easeOut(duration: 0.2)) { viewModel.select(ranked.route) }
                                    }
                                }
                            }.padding(.horizontal, 20).padding(.bottom, 2)
                        }

                        if let selected = viewModel.selectedRoute {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack { Text("Preference").font(.subheadline.weight(.semibold)); Spacer(); Text(preferenceText).font(.caption).foregroundStyle(.secondary) }
                                RiskPreferenceControl(preference: $viewModel.riskPreference)
                                Divider()
                                Button { showingDetails = true } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Why this route?").font(.subheadline.weight(.semibold))
                                            Text(explanationPreview(for: selected)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                            .padding(15)
                            .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 20)
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

    private var preferenceText: String {
        switch viewModel.riskPreference { case ..<0.34: return "Time-first"; case 0.67...: return "Exposure-first"; default: return "Balanced" }
    }

    private func explanationPreview(for route: NavigationRoute) -> String {
        let added = max(0, route.minutes - (viewModel.routes.map(\.minutes).min() ?? route.minutes))
        return added > 0 ? "Lower exposure for \(added) extra min" : "Fastest available option"
    }
}
