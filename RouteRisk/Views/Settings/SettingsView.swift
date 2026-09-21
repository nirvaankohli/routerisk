import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Demo") {
                    Button {
                        Task { await viewModel.loadDemo(); dismiss() }
                    } label: { Label("Load New Jersey demo", systemImage: "play.circle.fill") }
                    Text("Uses local representative crash data and does not require a network connection.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Location is used only to calculate your route", systemImage: "location.circle")
                    Text("RouteRisk does not make safety guarantees. Historical exposure is a relative estimate based on available crash records.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("About RouteRisk") {
                    HStack(spacing: 12) {
                        Image("RouteRiskLogo").resizable().scaledToFit().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading) { Text("RouteRisk").font(.headline); Text("Know the risk before you take the route.").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text("Version 1.0 · Congressional App Challenge demo build")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
