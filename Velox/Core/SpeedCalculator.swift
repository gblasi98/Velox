import Foundation

// MARK: - Speed Calculator

/// Core engine for computing average speed in Tutor zones.
///
/// Uses the Haversine formula to calculate the cumulative distance
/// traveled between GPS fixes, then divides by elapsed time to
/// produce the average speed.
///
/// Includes IMU-assisted dead reckoning for tunnel scenarios
/// where GPS signal is temporarily lost.
struct SpeedCalculator {
    // MARK: State
    private(set) var totalDistanceMeters: Double = 0.0
    private(set) var startTime: Date?
    private(set) var lastFix: GPSFix?
    private var fixCount: Int = 0

    // MARK: Configuration
    /// Maximum acceptable horizontal accuracy in meters.
    /// Fixes worse than this are discarded.
    static let maxAccuracy: Double = 20.0

    /// If no GPS fix for this many seconds, switch to IMU dead reckoning.
    static let gpsTimeout: TimeInterval = 5.0

    /// Earth's radius in meters (mean radius for Haversine).
    private static let earthRadiusMeters: Double = 6_371_000.0

    // MARK: - GPS Integration

    /// Feeds a new GPS fix into the calculator.
    /// - Returns: The updated average speed in km/h, or nil if the fix was rejected.
    @discardableResult
    mutating func processGPSFix(_ fix: GPSFix) -> Double? {
        // Reject low-accuracy fixes
        guard fix.horizontalAccuracy <= Self.maxAccuracy else {
            return currentAverageSpeedKmh()
        }

        // Initialize start time on first valid fix
        if startTime == nil {
            startTime = fix.timestamp
            lastFix = fix
            fixCount = 1
            return 0.0
        }

        // Calculate distance from last fix
        if let previous = lastFix {
            let distance = Self.haversineDistance(
                lat1: previous.latitude,
                lon1: previous.longitude,
                lat2: fix.latitude,
                lon2: fix.longitude
            )

            // Outlier rejection: skip unrealistic jumps
            // (e.g., > 100m in 1 second = 360 km/h)
            let timeDelta = fix.timestamp.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 && (distance / timeDelta) < 100.0 {
                totalDistanceMeters += distance
                fixCount += 1
            }
        }

        lastFix = fix
        return currentAverageSpeedKmh()
    }

    // MARK: - Dead Reckoning (IMU)

    /// Estimates distance traveled using IMU data when GPS is unavailable.
    /// Uses longitudinal acceleration integrated over time.
    ///
    /// - Parameters:
    ///   - acceleration: Longitudinal acceleration in m/s² (gravity-compensated).
    ///   - deltaTime: Time since last IMU sample in seconds.
    /// - Returns: Estimated distance added in meters.
    @discardableResult
    mutating func processIMU(acceleration: Double, deltaTime: TimeInterval) -> Double {
        // Simple integration: distance += v * dt + 0.5 * a * dt²
        // Uses the last known GPS speed as initial velocity (v0).
        let lastSpeed = lastFix?.speed ?? 0.0
        let estimatedDistance = lastSpeed * deltaTime + 0.5 * acceleration * deltaTime * deltaTime

        // Only accumulate if we're in a tunnel/GPS-loss scenario
        if let lastGps = lastFix {
            let gpsAge = Date().timeIntervalSince(lastGps.timestamp)
            if gpsAge > Self.gpsTimeout {
                totalDistanceMeters += max(0, estimatedDistance)
            }
        }

        return estimatedDistance
    }

    // MARK: - Average Speed

    /// Returns the current average speed in km/h.
    /// Returns 0 if tracking hasn't started.
    func currentAverageSpeedKmh() -> Double {
        guard let start = startTime else { return 0.0 }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0.0 }

        // km/h = (meters / 1000) / (seconds / 3600)
        return (totalDistanceMeters / 1000.0) / (elapsed / 3600.0)
    }

    /// Returns the elapsed tracking time in seconds.
    func elapsedTime() -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Returns the total number of valid GPS fixes processed.
    func processedFixCount() -> Int { fixCount }

    /// Resets the calculator for a new tracking session.
    mutating func reset() {
        totalDistanceMeters = 0.0
        startTime = nil
        lastFix = nil
        fixCount = 0
    }

    // MARK: - Haversine Formula

    /// Calculates the great-circle distance between two points
    /// on the Earth's surface using the Haversine formula.
    ///
    /// - Parameters:
    ///   - lat1, lon1: Coordinates of the first point in degrees.
    ///   - lat2, lon2: Coordinates of the second point in degrees.
    /// - Returns: Distance in meters.
    static func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let dLat = (lat2 - lat1).degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians
        let lat1Rad = lat1.degreesToRadians
        let lat2Rad = lat2.degreesToRadians

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }
}

// MARK: - GPS Fix

/// Represents a single GPS position fix with metadata.
struct GPSFix {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double // meters
    let speed: Double              // m/s (instantaneous, from GPS)
    let timestamp: Date
    let altitude: Double?
}

// MARK: - Tutor Record (SwiftData model placeholder)

import SwiftData

/// Persisted record of a completed Tutor zone traversal.
/// Stored locally via SwiftData for privacy.
@Model
final class TutorRecord {
    var startDate: Date
    var endDate: Date
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var totalDistanceKm: Double
    var averageSpeedKmh: Double
    var maxSpeedKmh: Double
    var gpsFixCount: Int
    var didEnterTunnel: Bool

    init(
        startDate: Date,
        endDate: Date,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        totalDistanceKm: Double,
        averageSpeedKmh: Double,
        maxSpeedKmh: Double,
        gpsFixCount: Int,
        didEnterTunnel: Bool
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.totalDistanceKm = totalDistanceKm
        self.averageSpeedKmh = averageSpeedKmh
        self.maxSpeedKmh = maxSpeedKmh
        self.gpsFixCount = gpsFixCount
        self.didEnterTunnel = didEnterTunnel
    }

    /// Time spent in the Tutor zone.
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Whether the driver exceeded the typical 130 km/h limit.
    var exceededLimit: Bool {
        averageSpeedKmh > 130.0
    }
}

// MARK: - Double Extension

extension Double {
    /// Converts degrees to radians.
    var degreesToRadians: Double {
        self * .pi / 180.0
    }
}
