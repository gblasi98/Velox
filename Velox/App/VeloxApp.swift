import SwiftUI

/// Main entry point for the Velox application.
///
/// Velox monitors your average speed in speed camera (Tutor) zones
/// and displays it as an overlay while you use Waze or other navigation apps.
///
/// Activation methods:
/// - Siri Shortcut: "Hey Siri, start Velox tracking"
/// - URL Scheme: `velox://start-tracking`
/// - CarPlay: Automatic on connection
/// - Manual: Tap "Start" in the app
@main
struct VeloxApp: App {
    @State private var trackingManager = TrackingManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(trackingManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    /// Handles deep link URLs for external activation.
    /// Supported schemes:
    /// - `velox://start-tracking` → begins speed monitoring
    /// - `velox://stop-tracking`  → stops monitoring
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return
        }

        switch host {
        case "start-tracking":
            trackingManager.startTracking()
        case "stop-tracking":
            trackingManager.stopTracking()
        default:
            print("[Velox] Unknown deep link: \(url.absoluteString)")
        }
    }
}

// MARK: - Tracking Manager (placeholder)

/// Central coordinator for the tracking lifecycle.
/// Manages location services, sensor fusion, and state machine.
/// Full implementation in Fase 2-3.
@Observable
final class TrackingManager {
    static let shared = TrackingManager()

    private(set) var isTracking = false
    private(set) var currentSpeed: Double = 0.0 // km/h
    private(set) var averageSpeed: Double = 0.0 // km/h
    private(set) var state: TrackingState = .idle

    private init() {}

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        state = .active
        print("[Velox] Tracking started")
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        state = .idle
        print("[Velox] Tracking stopped")
    }
}

// MARK: - Tracking State

enum TrackingState: String {
    case idle       // Not tracking
    case active     // Waiting for Tutor detection or GPS lock
    case tracking   // Actively computing average speed
    case gpsLost    // GPS signal lost (tunnel or urban canyon)
    case completed  // Tutor zone exited, summary available
}

// MARK: - Content View (placeholder)

struct ContentView: View {
    @Environment(TrackingManager.self) private var manager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Speed display
                VStack(spacing: 8) {
                    Text("\(Int(manager.averageSpeed))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                    Text("km/h average")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                // State indicator
                Text(manager.state.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(manager.isTracking ? .green : .secondary)

                Spacer()

                // Control button
                Button {
                    if manager.isTracking {
                        manager.stopTracking()
                    } else {
                        manager.startTracking()
                    }
                } label: {
                    Label(
                        manager.isTracking ? "Stop Tracking" : "Start Tracking",
                        systemImage: manager.isTracking ? "stop.fill" : "play.fill"
                    )
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
            }
            .navigationTitle("Velox")
            .padding()
        }
    }
}
