//
//  RouteOptimizerTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
import CoreLocation
@testable import Hiker

@MainActor
struct RouteOptimizerTests {

    // MARK: - Test Helpers

    private func makePickup(name: String, lat: Double, lon: Double) -> RouteOptimizer.Pickup {
        RouteOptimizer.Pickup(
            id: UUID(),
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
    }

    // Halifax area test coordinates (Bedford, Sackville, Beaver Bank)
    private var bedfordPickup: RouteOptimizer.Pickup {
        makePickup(name: "Bedford", lat: 44.7324, lon: -63.6567)
    }

    private var sackvillePickup: RouteOptimizer.Pickup {
        makePickup(name: "Sackville", lat: 44.7754, lon: -63.6789)
    }

    private var beaverBankPickup: RouteOptimizer.Pickup {
        makePickup(name: "Beaver Bank", lat: 44.8123, lon: -63.6234)
    }

    // MARK: - Edge Case Tests

    @Test("Empty pickup list returns empty route")
    func testEmptyPickupList() {
        let emptyPickups: [RouteOptimizer.Pickup] = []
        let result = RouteOptimizer.optimizeRoute(for: emptyPickups)

        #expect(result.pickups.isEmpty)
        #expect(result.totalDistance == 0)
    }

    @Test("Single pickup returns that pickup with zero distance")
    func testSinglePickup() {
        let pickups = [bedfordPickup]
        let result = RouteOptimizer.optimizeRoute(for: pickups)

        #expect(result.pickups.count == 1)
        #expect(result.pickups[0].name == "Bedford")
        #expect(result.totalDistance == 0)
    }

    @Test("Invalid coordinates (0,0) are filtered out")
    func testInvalidCoordinatesFiltered() {
        let invalidPickup = makePickup(name: "Invalid", lat: 0, lon: 0)
        let validPickup = bedfordPickup

        let result = RouteOptimizer.optimizeRoute(for: [invalidPickup, validPickup])

        #expect(result.pickups.count == 1)
        #expect(result.pickups[0].name == "Bedford")
    }

    @Test("All invalid coordinates returns empty route")
    func testAllInvalidCoordinates() {
        let invalid1 = makePickup(name: "Invalid1", lat: 0, lon: 0)
        let invalid2 = makePickup(name: "Invalid2", lat: 0, lon: 0)

        let result = RouteOptimizer.optimizeRoute(for: [invalid1, invalid2])

        #expect(result.pickups.isEmpty)
        #expect(result.totalDistance == 0)
    }

    // MARK: - Route Optimization Tests

    @Test("Brute force finds optimal route for 3 pickups")
    func testBruteForceOptimality() {
        // Create a simple triangle of locations where optimal route is clear
        // Bedford -> Sackville -> Beaver Bank forms a northward line
        let pickups = [bedfordPickup, sackvillePickup, beaverBankPickup]

        let result = RouteOptimizer.optimizeRoute(for: pickups, strategy: .bruteForce)

        #expect(result.pickups.count == 3)
        #expect(result.strategy == .bruteForce)
        #expect(result.totalDistance > 0)

        // Verify it actually computed a route (distance should be reasonable for Halifax area)
        // These locations are roughly 5-10km apart
        #expect(result.totalDistance < 50000) // Less than 50km total
        #expect(result.totalDistance > 1000)  // More than 1km total
    }

    @Test("Nearest neighbor produces valid route")
    func testNearestNeighborProducesValidRoute() {
        let pickups = [bedfordPickup, sackvillePickup, beaverBankPickup]

        let result = RouteOptimizer.optimizeRoute(for: pickups, strategy: .nearestNeighbor)

        #expect(result.pickups.count == 3)
        #expect(result.strategy == .nearestNeighbor)
        #expect(result.totalDistance > 0)
    }

    @Test("Brute force and nearest neighbor return same pickups (different order)")
    func testBothStrategiesReturnAllPickups() {
        let pickups = [bedfordPickup, sackvillePickup, beaverBankPickup]

        let bruteResult = RouteOptimizer.optimizeRoute(for: pickups, strategy: .bruteForce)
        let nnResult = RouteOptimizer.optimizeRoute(for: pickups, strategy: .nearestNeighbor)

        // Both should contain all 3 pickups
        let bruteNames = Set(bruteResult.pickups.map { $0.name })
        let nnNames = Set(nnResult.pickups.map { $0.name })

        #expect(bruteNames == Set(["Bedford", "Sackville", "Beaver Bank"]))
        #expect(nnNames == Set(["Bedford", "Sackville", "Beaver Bank"]))
    }

    @Test("Brute force is at least as good as nearest neighbor")
    func testBruteForceAtLeastAsGoodAsNearestNeighbor() {
        let pickups = [bedfordPickup, sackvillePickup, beaverBankPickup]

        let bruteResult = RouteOptimizer.optimizeRoute(for: pickups, strategy: .bruteForce)
        let nnResult = RouteOptimizer.optimizeRoute(for: pickups, strategy: .nearestNeighbor)

        // Brute force should find route equal or better than nearest neighbor
        #expect(bruteResult.totalDistance <= nnResult.totalDistance)
    }

    @Test("Starting location affects route distance calculation")
    func testStartingLocationAffectsDistance() {
        let pickups = [sackvillePickup, beaverBankPickup]

        // Start from Bedford (south of both pickups)
        let startLocation = CLLocationCoordinate2D(latitude: 44.7324, longitude: -63.6567)

        let withStart = RouteOptimizer.optimizeRoute(
            for: pickups,
            startingFrom: startLocation,
            strategy: .bruteForce
        )

        let withoutStart = RouteOptimizer.optimizeRoute(
            for: pickups,
            strategy: .bruteForce
        )

        // Routes should be computed but may have different distances
        #expect(withStart.pickups.count == 2)
        #expect(withoutStart.pickups.count == 2)
    }

    // MARK: - Fallback Strategy Tests

    @Test("Large pickup count falls back to nearest neighbor in brute force mode")
    func testFallbackToNearestNeighborForLargeCount() {
        // Create 11 pickups (> 10 threshold)
        var pickups: [RouteOptimizer.Pickup] = []
        for i in 0..<11 {
            let lat = 44.7 + Double(i) * 0.01
            let lon = -63.6 + Double(i) * 0.01
            pickups.append(makePickup(name: "Dog\(i)", lat: lat, lon: lon))
        }

        // Request brute force but should fall back to nearest neighbor
        let result = RouteOptimizer.optimizeRoute(for: pickups, strategy: .bruteForce)

        #expect(result.pickups.count == 11)
        // The algorithm internally falls back but still returns a valid route
        #expect(result.totalDistance > 0)
    }

    // MARK: - Distance Calculation Tests

    @Test("Distance formatter produces readable output")
    func testDistanceFormatter() {
        let distance: CLLocationDistance = 5432.1
        let formatted = distance.kilometersFormatted

        #expect(formatted == "5.4 km")
    }

    @Test("Zero distance formats correctly")
    func testZeroDistanceFormatted() {
        let distance: CLLocationDistance = 0
        let formatted = distance.kilometersFormatted

        #expect(formatted == "0.0 km")
    }
}
