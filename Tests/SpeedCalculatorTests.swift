import Testing
@testable import Velox

// MARK: - Haversine Distance Tests

struct HaversineDistanceTests {

    @Test("Zero distance for same point")
    func zeroDistanceForSamePoint() {
        let dist = SpeedCalculator.haversineDistance(
            lat1: 45.0, lon1: 9.0,
            lat2: 45.0, lon2: 9.0
        )
        #expect(dist == 0.0)
    }

    @Test("Short known distance (~111m per 0.001 degrees latitude)")
    func shortKnownDistance() {
        // 0.001 degrees latitude ≈ 111 meters
        let dist = SpeedCalculator.haversineDistance(
            lat1: 45.0, lon1: 9.0,
            lat2: 45.001, lon2: 9.0
        )
        #expect(dist > 100 && dist < 120)
    }

    @Test("Long distance approximates known values")
    func longDistance() {
        // Milan (45.4642, 9.1900) to Rome (41.9028, 12.4964) ≈ 477 km
        let dist = SpeedCalculator.haversineDistance(
            lat1: 45.4642, lon1: 9.1900,
            lat2: 41.9028, lon2: 12.4964
        )
        let distKm = dist / 1000
        #expect(distKm > 450 && distKm < 500)
    }

    @Test("Equator crossing produces valid distance")
    func equatorCrossing() {
        let dist = SpeedCalculator.haversineDistance(
            lat1: -1.0, lon1: 0.0,
            lat2: 1.0, lon2: 0.0
        )
        #expect(dist > 200_000 && dist < 250_000) // ~222 km for 2 degrees
    }

    @Test("Antimeridian crossing handled correctly")
    func antimeridianCrossing() {
        let dist = SpeedCalculator.haversineDistance(
            lat1: 0.0, lon1: 179.0,
            lat2: 0.0, lon2: -179.0
        )
        #expect(dist > 200_000 && dist < 250_000) // ~222 km for 2 degrees
    }
}

// MARK: - Speed Calculator Tests

struct SpeedCalculatorTests {

    @Test("Initial state has zero average speed")
    func initialZeroSpeed() {
        let calc = SpeedCalculator()
        #expect(calc.currentAverageSpeedKmh() == 0.0)
        #expect(calc.elapsedTime() == 0.0)
        #expect(calc.processedFixCount() == 0)
    }

    @Test("Single valid fix starts tracking")
    func singleValidFix() {
        var calc = SpeedCalculator()
        let fix = GPSFix(
            latitude: 45.0, longitude: 9.0,
            horizontalAccuracy: 5.0,
            speed: 30.0,
            timestamp: Date(),
            altitude: nil
        )
        let result = calc.processGPSFix(fix)
        #expect(result == 0.0) // 0 km/h because only one fix
        #expect(calc.processedFixCount() == 1)
    }

    @Test("Inaccurate fix is rejected")
    func inaccurateFixRejected() {
        var calc = SpeedCalculator()
        let badFix = GPSFix(
            latitude: 45.0, longitude: 9.0,
            horizontalAccuracy: 50.0, // > 20m threshold
            speed: 30.0,
            timestamp: Date(),
            altitude: nil
        )
        let result = calc.processGPSFix(badFix)
        #expect(result == 0.0)
        #expect(calc.processedFixCount() == 0)
    }

    @Test("Two valid fixes compute positive average speed")
    func twoFixesComputeSpeed() {
        var calc = SpeedCalculator()

        let fix1 = GPSFix(
            latitude: 45.0, longitude: 9.0,
            horizontalAccuracy: 5.0,
            speed: 36.0, // ~130 km/h
            timestamp: Date(),
            altitude: nil
        )

        // 1 second later, ~36 meters moved (130 km/h)
        let fix2 = GPSFix(
            latitude: 45.0, longitude: 9.00036,
            horizontalAccuracy: 5.0,
            speed: 36.0,
            timestamp: Date().addingTimeInterval(1.0),
            altitude: nil
        )

        calc.processGPSFix(fix1)

        // Use a small delay to ensure time passes
        Thread.sleep(forTimeInterval: 0.1)

        let avg = calc.processGPSFix(fix2)
        #expect(avg != nil)
        #expect(avg! > 0.0)
        #expect(calc.processedFixCount() == 2)
    }

    @Test("Unrealistic jump is filtered out")
    func unrealisticJumpFiltered() {
        var calc = SpeedCalculator()

        let fix1 = GPSFix(
            latitude: 45.0, longitude: 9.0,
            horizontalAccuracy: 5.0,
            speed: 10.0,
            timestamp: Date(),
            altitude: nil
        )

        // 500 meters in 1 second = 1800 km/h → should be rejected
        let fix2 = GPSFix(
            latitude: 45.0045, longitude: 9.0,
            horizontalAccuracy: 5.0,
            speed: 500.0,
            timestamp: Date().addingTimeInterval(1.0),
            altitude: nil
        )

        calc.processGPSFix(fix1)
        let avg = calc.processGPSFix(fix2)

        // Total distance should still be 0 (the jump was rejected)
        #expect(avg != nil)
        #expect(calc.processedFixCount() == 1) // only first fix counted
    }

    @Test("Reset clears all state")
    func resetClearsState() {
        var calc = SpeedCalculator()

        let fix = GPSFix(
            latitude: 45.0, longitude: 9.0,
            horizontalAccuracy: 5.0,
            speed: 30.0,
            timestamp: Date(),
            altitude: nil
        )
        calc.processGPSFix(fix)

        calc.reset()
        #expect(calc.currentAverageSpeedKmh() == 0.0)
        #expect(calc.processedFixCount() == 0)
        #expect(calc.elapsedTime() == 0.0)
    }
}

// MARK: - Tutor Record Tests

struct TutorRecordTests {

    @Test("Duration is computed correctly")
    func durationComputed() {
        let start = Date()
        let end = start.addingTimeInterval(420) // 7 minutes
        let record = TutorRecord(
            startDate: start,
            endDate: end,
            startLatitude: 45.0,
            startLongitude: 9.0,
            endLatitude: 45.1,
            endLongitude: 9.0,
            totalDistanceKm: 11.1,
            averageSpeedKmh: 95.0,
            maxSpeedKmh: 140.0,
            gpsFixCount: 420,
            didEnterTunnel: false
        )
        #expect(record.duration == 420.0)
    }

    @Test("Exceeded limit detection")
    func exceededLimitDetection() {
        let speeding = TutorRecord(
            startDate: Date(),
            endDate: Date(),
            startLatitude: 0, startLongitude: 0,
            endLatitude: 0, endLongitude: 0,
            totalDistanceKm: 10,
            averageSpeedKmh: 135.0, // > 130
            maxSpeedKmh: 150,
            gpsFixCount: 100,
            didEnterTunnel: false
        )
        #expect(speeding.exceededLimit)

        let legal = TutorRecord(
            startDate: Date(),
            endDate: Date(),
            startLatitude: 0, startLongitude: 0,
            endLatitude: 0, endLongitude: 0,
            totalDistanceKm: 10,
            averageSpeedKmh: 120.0, // < 130
            maxSpeedKmh: 125,
            gpsFixCount: 100,
            didEnterTunnel: false
        )
        #expect(!legal.exceededLimit)
    }
}
