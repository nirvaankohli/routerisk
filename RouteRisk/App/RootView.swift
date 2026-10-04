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
    static let canvas = Color(red: 0.035, green: 0.055, blue: 0.090)
    static let surface = Color(red: 0.070, green: 0.100, blue: 0.150)
    static let elevatedSurface = Color(red: 0.105, green: 0.140, blue: 0.195)
    static let action = Color(red: 0.075, green: 0.480, blue: 0.953)
    static let accent = Color(red: 0.300, green: 0.800, blue: 0.890)
    static let subduedText = Color.white.opacity(0.64)
}
