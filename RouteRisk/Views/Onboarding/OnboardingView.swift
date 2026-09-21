import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var locationService: LocationService
    @State private var page = 0

    private let pages: [(symbol: String, title: String, body: String)] = [
        ("point.topleft.down.curvedto.point.bottomright.up", "Know the risk before you take the route.", "RouteRisk compares travel time with historical crash exposure."),
        ("arrow.left.arrow.right.circle.fill", "See the tradeoff.", "Understand why one route may have lower historical exposure than another."),
        ("location.fill", "Use your location, on your terms.", "RouteRisk only requests location to find routes. No account is needed.")
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image("RouteRiskLogo").resizable().scaledToFit().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text("ROUTERISK").font(.subheadline.weight(.heavy)).tracking(1.1)
                    Spacer()
                    if page < pages.count - 1 { Button("Skip") { hasCompletedOnboarding = true }.foregroundStyle(.secondary) }
                }.padding(.horizontal, 24).padding(.top, 18)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 24) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.11)).frame(width: 132, height: 132)
                                Image(systemName: item.symbol).font(.system(size: 50, weight: .medium)).foregroundStyle(.blue)
                            }
                            VStack(spacing: 12) {
                                Text(item.title).font(.system(size: 31, weight: .bold, design: .rounded)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                Text(item.body).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 310)
                            }
                        }.tag(index).padding(.horizontal, 24)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page == pages.count - 1 { locationService.requestLocation(); hasCompletedOnboarding = true } else { withAnimation(.easeOut(duration: 0.2)) { page += 1 } }
                } label: {
                    Text(page == pages.count - 1 ? "Enable location" : "Continue").font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                }
                .buttonStyle(.borderedProminent).tint(.blue).padding(.horizontal, 24).padding(.bottom, 38)
            }
        }
    }
}
