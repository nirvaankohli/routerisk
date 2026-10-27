import CoreLocation
import CoreMotion
import MessageUI
import Security
import SwiftUI

enum ParentContact {
    static func phoneNumber(from raw: String) -> String? {
        let digits = raw.filter { "0123456789".contains($0) }
        guard (10...15).contains(digits.count) else { return nil }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") ? "+\(digits)" : digits
    }
}

enum SafetyEvent: String, Encodable {
    case departure, arrival, possibleCrash
}

enum PairingTokenStore {
    private static let service = "com.routerisk.app.parent-updates"
    private static let account = "delivery-service-token"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty else { return true }
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}

struct SafetyBackendClient {
    private struct Payload: Encodable {
        let event: SafetyEvent
        let recipient: String
        let destination: String
        let latitude: Double?
        let longitude: Double?
        let timeText: String?
        let eventID: UUID
    }

    private var baseURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: "safetyServiceURL"),
              let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host?.lowercased() ?? ""))
        else { return nil }
        return url
    }

    var isConfigured: Bool { baseURL != nil && PairingTokenStore.read() != nil }

    func send(_ event: SafetyEvent, to recipient: String, destination: String, location: CLLocationCoordinate2D?, timeText: String? = nil) async throws {
        guard let baseURL, let token = PairingTokenStore.read() else { throw DeliveryError.notConfigured }
        let url = baseURL.appendingPathComponent("api/notify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Payload(event: event, recipient: recipient, destination: destination,
                                                              latitude: location?.latitude, longitude: location?.longitude,
                                                              timeText: timeText, eventID: UUID()))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw DeliveryError.failed
        }
    }

    func checkConnection() async -> Bool {
        guard let baseURL, let token = PairingTokenStore.read() else { return false }
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let response = response as? HTTPURLResponse else { return false }
        return response.statusCode == 200
    }

    enum DeliveryError: Error { case notConfigured, failed }
}

struct SafetyMessage: Identifiable {
    let id = UUID()
    let recipient: String
    let title: String
    let body: String

    static func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
            .replacingOccurrences(of: "AM", with: "A.M.")
            .replacingOccurrences(of: "PM", with: "P.M.")
    }

    static func departure(to recipient: String, destination: String, eta: String) -> Self {
        Self(recipient: recipient, title: "Trip started",
             body: "Your child has started a route to \(destination). ETA: \(eta)")
    }

    static func arrival(to recipient: String, destination: String, at time: String) -> Self {
        Self(recipient: recipient, title: "Arrived",
             body: "Your child has arrived at \(destination) at \(time)")
    }
}

struct SafetyMessageSheet: View {
    let message: SafetyMessage

    var body: some View {
        if MFMessageComposeViewController.canSendText() {
            MessageComposer(message: message)
        } else {
            MessagePreview(message: message)
        }
    }
}

private struct MessageComposer: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let message: SafetyMessage

    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [message.recipient]
        controller.body = message.body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish()
        }
    }
}

private struct MessagePreview: View {
    @Environment(\.dismiss) private var dismiss
    let message: SafetyMessage

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Messages is unavailable on this device", systemImage: "message")
                    .font(.headline)
                Text("On an iPhone that can send texts, RouteRisk opens this message with the parent number filled in. You still tap Send.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("To: \(message.recipient)")
                    .font(.subheadline.weight(.semibold))
                Text(message.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RouteRiskTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16))
                Button("Copy message") { UIPasteboard.general.string = message.body }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(20)
            .navigationTitle(message.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

/// A conservative signal for a *possible* crash, not a validated crash detector.
struct ImpactHeuristic {
    private var lastDrivingTime: TimeInterval?
    private var impactTime: TimeInterval?

    mutating func observeSpeed(_ metersPerSecond: Double, at time: TimeInterval) -> Bool {
        guard metersPerSecond >= 0 else { return false }
        if metersPerSecond >= 8 { lastDrivingTime = time }
        guard let impactTime else { return false }
        if time - impactTime > 8 {
            self.impactTime = nil
            return false
        }
        if metersPerSecond <= 2.5 {
            self.impactTime = nil
            lastDrivingTime = nil
            return true
        }
        return false
    }

    mutating func observeImpact(_ accelerationG: Double, at time: TimeInterval) {
        guard accelerationG >= 3.6, let lastDrivingTime, time - lastDrivingTime <= 5 else { return }
        impactTime = time
    }
}

@MainActor
final class TripImpactMonitor: ObservableObject {
    @Published var suspectedImpact = false
    @Published private(set) var isMonitoring = false

    private let motion = CMMotionManager()
    private var detector = ImpactHeuristic()

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard !isMonitoring, isAvailable else { return }
        detector = ImpactHeuristic()
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let sample else { return }
            let acceleration = sample.userAcceleration
            let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
            Task { @MainActor [weak self] in
                self?.detector.observeImpact(magnitude, at: Date().timeIntervalSinceReferenceDate)
            }
        }
        isMonitoring = true
    }

    func observeSpeed(_ speed: CLLocationSpeed?) {
        guard isMonitoring, let speed else { return }
        if detector.observeSpeed(speed, at: Date().timeIntervalSinceReferenceDate) {
            stop()
            suspectedImpact = true
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        isMonitoring = false
        detector = ImpactHeuristic()
    }

}
