import SwiftUI

enum DirectionsMode: String, CaseIterable {
    case car = "Car"
    case walk = "Walk"
    case bike = "Bike"
    case subway = "Subway"

    var icon: String {
        switch self {
        case .car: "MuiDirectionsCar"
        case .walk: "MuiDirectionsWalk"
        case .bike: "MuiDirectionsBike"
        case .subway: "MuiSubway"
        }
    }
}

struct RouteComparisonSheet: View {
    static let expandedHeight: CGFloat = 420
    static let collapsedHeight: CGFloat = 118

    @EnvironmentObject private var viewModel: NavigationViewModel
    @Binding var showingDetails: Bool
    @Binding var isExpanded: Bool
    @Binding var selectedMode: DirectionsMode
    let onClose: () -> Void
    let onGo: (NavigationRoute) -> Void
    @GestureState private var dragTranslation: CGFloat = 0

    init(showingDetails: Binding<Bool>, isExpanded: Binding<Bool>, selectedMode: Binding<DirectionsMode>, onClose: @escaping () -> Void, onGo: @escaping (NavigationRoute) -> Void) {
        _showingDetails = showingDetails
        _isExpanded = isExpanded
        _selectedMode = selectedMode
        self.onClose = onClose
        self.onGo = onGo
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
            .accessibilityLabel(isExpanded ? "Collapse directions" : "Expand directions")

            if isExpanded {
                expandedContent
            } else {
                compactSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: isExpanded ? Self.expandedHeight : Self.collapsedHeight, alignment: .top)
        .safeAreaPadding(.bottom, 8)
        .background(RouteRiskTheme.surface)
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
                if selectedMode != .car {
                    MaterialIcon(name: selectedMode.icon, size: 21)
                        .foregroundStyle(RouteRiskTheme.action)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Directions").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text("\(selectedMode.rawValue) directions coming soon")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else if let selected = viewModel.selectedRoute {
                    Image(systemName: hasExposureData ? selected.exposure.level.symbol : "clock.fill")
                        .foregroundStyle(hasExposureData ? selected.exposure.level.color : RouteRiskTheme.action)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Directions").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(hasExposureData ? "\(selected.minutes) min · \(selected.kind.title) · \(selected.exposure.level.title) exposure" : "\(selected.minutes) min · Exposure data unavailable")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    HStack(spacing: 10) {
                        MaterialIcon(name: "MuiMapOutlined", size: 20)
                        Text("Directions").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                }
                Spacer()
                MaterialIcon(name: "MuiKeyboardArrowUp", size: 22).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to show directions")
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Directions")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onClose) {
                    MaterialIcon(name: "MuiClose", size: 21)
                        .foregroundStyle(RouteRiskTheme.subduedText)
                        .frame(width: 38, height: 38)
                        .background(RouteRiskTheme.elevatedSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close directions")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 9)

            modeSelector
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if selectedMode == .car {
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {

                        if viewModel.isLoading {
                            ProgressView("Finding route alternatives…").padding(.horizontal, 20)
                        } else {
                            if let message = viewModel.errorMessage {
                                Label(message, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                            }
                            if case let .unavailable(reason) = viewModel.crashDataStatus {
                                Label(reason, systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                            }
                            if !viewModel.rankedRoutes.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.rankedRoutes.indices, id: \.self) { index in
                                        routeRow(viewModel.rankedRoutes[index])
                                        if index < viewModel.rankedRoutes.count - 1 {
                                            Rectangle()
                                                .fill(.white.opacity(0.10))
                                                .frame(height: 1)
                                                .padding(.leading, 46)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                if hasExposureData { preferenceControl }
                                if viewModel.selectedRoute != nil {
                                    Button { showingDetails = true } label: {
                                        HStack(spacing: 7) {
                                            MaterialIcon(name: "MuiInfoOutlined", size: 18)
                                            Text("Why this route?")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RouteRiskTheme.subduedText)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 18)
                }
            } else {
                VStack(spacing: 10) {
                    MaterialIcon(name: selectedMode.icon, size: 32)
                        .foregroundStyle(RouteRiskTheme.action)
                    Text("\(selectedMode.rawValue) directions are coming soon")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Driving routes are available now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Show driving routes") { selectedMode = .car }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RouteRiskTheme.action)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 24)
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 3) {
            ForEach(DirectionsMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selectedMode = mode }
                } label: {
                    MaterialIcon(name: mode.icon, size: 23)
                    .foregroundStyle(selectedMode == mode ? .white : RouteRiskTheme.subduedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(selectedMode == mode ? Color(red: 0.27, green: 0.27, blue: 0.27) : .clear, in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.rawValue) directions")
                .accessibilityAddTraits(selectedMode == mode ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(RouteRiskTheme.elevatedSurface, in: Capsule())
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
        return HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { viewModel.select(route) }
            } label: {
                HStack(spacing: 12) {
                    MaterialIcon(name: viewModel.selectedRouteID == route.id ? "MuiCheckCircle" : "MuiRadioButtonUnchecked", size: 22)
                        .foregroundStyle(viewModel.selectedRouteID == route.id ? RouteRiskTheme.action : RouteRiskTheme.subduedText)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("\(route.minutes) min")
                                .font(.title3.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.primary)
                            Text(route.kind.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(hasExposureData ? "\(route.miles, specifier: "%.1f") mi · \(route.exposure.level.title) exposure" : "\(route.miles, specifier: "%.1f") mi · Exposure unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasExposureData ? "Select \(route.kind.title), \(route.minutes) minutes, \(route.exposure.level.title) historical exposure" : "Select \(route.kind.title), \(route.minutes) minutes")

            Button {
                viewModel.select(route)
                onGo(route)
            } label: {
                Text("GO")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color(red: 0.29, green: 0.94, blue: 0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go on \(route.kind.title) route")
        }
        .padding(.horizontal, 14)
        .frame(height: 78)
        .background(viewModel.selectedRouteID == route.id ? Color(red: 0.24, green: 0.24, blue: 0.24) : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var hasExposureData: Bool {
        if case .unavailable = viewModel.crashDataStatus { return false }
        return true
    }

    private var preferenceText: String {
        switch viewModel.riskPreference { case ..<0.34: return "Time-first"; case 0.67...: return "Exposure-first"; default: return "Balanced" }
    }

}
