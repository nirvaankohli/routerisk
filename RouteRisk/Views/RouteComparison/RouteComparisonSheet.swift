import SwiftUI

struct RouteComparisonSheet: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Binding var showingDetails: Bool
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.tertiary).frame(width: 38, height: 5).padding(.top, 9).padding(.bottom, 11)
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Route tradeoff").font(.headline)
                            Text(viewModel.destinationName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if viewModel.usesDemoData {
                            Label("Demo Data", systemImage: "testtube.2").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 9).padding(.vertical, 6).background(.secondary.opacity(0.1), in: Capsule())
                        }
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
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 18)
            }
            .scrollDisabled(!expanded)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: -4)
        .gesture(DragGesture().onEnded { value in if abs(value.translation.height) > 25 { expanded = value.translation.height < 0 } })
        .accessibilityElement(children: .contain)
    }

    private var preferenceText: String {
        switch viewModel.riskPreference { case ..<0.34: return "Time-first"; case 0.67...: return "Exposure-first"; default: return "Balanced" }
    }

    private func explanationPreview(for route: NavigationRoute) -> String {
        let added = max(0, route.minutes - (viewModel.routes.map(\.minutes).min() ?? route.minutes))
        return added > 0 ? "Lower exposure for \(added) extra min" : "Fastest available option"
    }
}
