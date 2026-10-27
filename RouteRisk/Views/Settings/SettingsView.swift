import CoreLocation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: NavigationViewModel
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("parentPhoneNumber") private var parentPhoneNumber = ""
    @AppStorage("tripUpdatesEnabled") private var tripUpdatesEnabled = false
    @AppStorage("impactAlertsEnabled") private var impactAlertsEnabled = false
    @AppStorage("liveIncidentAlertsEnabled") private var liveIncidentAlertsEnabled = true
    @AppStorage("routeRisk.guidedShowcaseEnabled") private var guidedShowcaseEnabled = false
    @AppStorage("safetyServiceURL") private var safetyServiceURL = ""
    @State private var accessCode = PairingTokenStore.read() ?? ""
    @State private var connectionStatus: String?
    let onStartShowcase: () -> Void
    let onStopShowcase: () -> Void

    init(onStartShowcase: @escaping () -> Void = {}, onStopShowcase: @escaping () -> Void = {}) {
        self.onStartShowcase = onStartShowcase
        self.onStopShowcase = onStopShowcase
    }

    private var hasParentNumber: Bool { ParentContact.phoneNumber(from: parentPhoneNumber) != nil }
    private var locationStatus: String {
        if guidedShowcaseEnabled { return "Guided showcase uses an animated position" }
        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            return "Location access is off"
        }
        return locationService.currentLocation == nil ? "Waiting for this iPhone's location" : "Using this iPhone's current location"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Crash reports ahead") {
                    Toggle("Alert and reroute during an active trip", isOn: $liveIncidentAlertsEnabled)
                    Text("RouteRisk checks active 511NJ crash reports about once a minute while the app is open. If a report is ahead, it warns you and looks for a route around the reported location. If no alternate is clear, it keeps your route. Reports can be delayed or imprecise.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Parent contact") {
                    TextField("Parent phone number", text: $parentPhoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .onChange(of: parentPhoneNumber) { _, _ in reconcileParentSettings() }
                    if !parentPhoneNumber.isEmpty && !hasParentNumber {
                        Text("Enter a phone number with 10 to 15 digits.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    Toggle("Trip start and arrival updates", isOn: $tripUpdatesEnabled)
                        .disabled(!hasParentNumber)
                    Text("Text your parent when you tap GO and when you arrive. Automatic delivery requires a connected service; otherwise, you tap Send in Messages.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Possible crash check") {
                    Toggle("Check for a strong impact", isOn: $impactAlertsEnabled)
                        .disabled(!hasParentNumber)
                    Text("A strong impact and sudden stop starts a 20-second check. If you don't cancel, the service texts and calls your parent.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Experimental · Only while navigating with the app open. It can miss crashes or trigger after a jolt. Without the service, iOS asks you to confirm a call. Do not rely on this for emergency response.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Automatic delivery service") {
                    TextField("Service URL (https://…)", text: $safetyServiceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Access code", text: $accessCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: accessCode) { _, newValue in
                            PairingTokenStore.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                            connectionStatus = nil
                        }
                    Button("Check connection") {
                        Task {
                            connectionStatus = await SafetyBackendClient().checkConnection()
                                ? "Service configured. Delivery depends on your Twilio account."
                                : "Service unavailable. Trip updates will open in Messages."
                        }
                    }
                    if let connectionStatus { Text(connectionStatus).font(.footnote).foregroundStyle(.secondary) }
                    Text("Your Twilio credentials stay on your server. This iPhone stores only its access code.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Historical data") {
                    Label(viewModel.crashDataStatus.detail, systemImage: viewModel.crashDataStatus.systemImage)
                        .foregroundStyle(viewModel.crashDataStatus == .live ? .primary : .secondary)
                }
                Section("Presentation") {
                    Toggle("Guided showcase", isOn: $guidedShowcaseEnabled)
                        .onChange(of: guidedShowcaseEnabled) { _, enabled in
                            if enabled {
                                dismiss()
                                onStartShowcase()
                            } else {
                                onStopShowcase()
                            }
                        }
                    Text("Animates a route and a practice crash report so you can record the navigation flow without driving. This scenario is separate from live location and 511NJ alerts; it never contacts a parent.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                    Label(locationStatus, systemImage: "location.circle")
                    Button("Refresh my location") { locationService.requestLocation() }
                    Text("RouteRisk does not make safety guarantees. Historical exposure is a relative estimate based on available crash records.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("About RouteRisk") {
                    HStack(spacing: 12) {
                        Image("RouteRiskLogo").resizable().scaledToFit().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading) { Text("RouteRisk").font(.headline); Text("Know the risk before you take the route.").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text("Version 1.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { reconcileParentSettings() }
        }
    }

    private func reconcileParentSettings() {
        guard !hasParentNumber else { return }
        tripUpdatesEnabled = false
        impactAlertsEnabled = false
    }
}
