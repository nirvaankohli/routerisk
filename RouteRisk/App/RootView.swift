import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                NavigationHomeView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .tint(RouteRiskTheme.action)
        .preferredColorScheme(.dark)
    }
}

enum RouteRiskTheme {
    static let canvas = Color(red: 0.075, green: 0.075, blue: 0.075)
    static let surface = Color(red: 0.16, green: 0.16, blue: 0.16)
    static let elevatedSurface = Color(red: 0.21, green: 0.21, blue: 0.21)
    static let action = Color(red: 0.039, green: 0.518, blue: 1.0)
    static let accent = action
    static let subduedText = Color.white.opacity(0.66)
}
