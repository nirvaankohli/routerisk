import SwiftUI

struct RiskPreferenceControl: View {
    @Binding var preference: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Faster", systemImage: "gauge.with.dots.needle.33percent")
                Spacer()
                Label("Lower exposure", systemImage: "shield.lefthalf.filled")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            Slider(value: $preference, in: 0...1)
                .tint(RouteRiskTheme.action)
                .accessibilityLabel("Route preference, faster to lower historical exposure")
                .accessibilityValue("\(Int(preference * 100)) percent toward lower historical exposure")
        }
    }
}
