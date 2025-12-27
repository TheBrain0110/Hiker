//
//  RouteOptimizer.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import CoreLocation

/// Optimizes pickup routes for dogs to minimize total travel distance
struct RouteOptimizer {

    /// Strategy for route optimization
    enum Strategy {
        case nearestNeighbor  // Greedy algorithm, fast but ~85% optimal
        case bruteForce       // Tries all permutations, optimal but slower (fine for ≤8 dogs)
    }

    /// Represents a dog with its pickup location
    struct Pickup: Identifiable {
        let id: UUID
        let name: String
        let coordinate: CLLocationCoordinate2D

        init(id: UUID, name: String, coordinate: CLLocationCoordinate2D) {
            self.id = id
            self.name = name
            self.coordinate = coordinate
        }

        init(from dog: Dog) {
            self.id = dog.id
            self.name = dog.name
            self.coordinate = dog.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }

    /// Result of route optimization
    struct OptimizedRoute {
        let pickups: [Pickup]              // Ordered list of pickups
        let totalDistance: CLLocationDistance  // Total distance in meters
        let strategy: Strategy
    }

    // MARK: - Public API

    /// Optimizes the pickup order for a list of dogs
    /// - Parameters:
    ///   - pickups: List of pickups to optimize
    ///   - startLocation: Optional starting location (e.g., operator's home)
    ///   - strategy: Optimization strategy to use
    /// - Returns: Optimized route with total distance
    static func optimizeRoute(
        for pickups: [Pickup],
        startingFrom startLocation: CLLocationCoordinate2D? = nil,
        strategy: Strategy = .bruteForce
    ) -> OptimizedRoute {
        // Handle edge cases
        guard !pickups.isEmpty else {
            return OptimizedRoute(pickups: [], totalDistance: 0, strategy: strategy)
        }

        if pickups.count == 1 {
            return OptimizedRoute(pickups: pickups, totalDistance: 0, strategy: strategy)
        }

        // Filter out any pickups with invalid coordinates
        let validPickups = pickups.filter { isValidCoordinate($0.coordinate) }

        guard !validPickups.isEmpty else {
            return OptimizedRoute(pickups: [], totalDistance: 0, strategy: strategy)
        }

        // Choose optimization strategy
        switch strategy {
        case .nearestNeighbor:
            return nearestNeighborRoute(for: validPickups, startingFrom: startLocation)
        case .bruteForce:
            return bruteForceRoute(for: validPickups, startingFrom: startLocation)
        }
    }

    /// Convenience method that accepts Dog objects directly
    static func optimizeRoute(
        for dogs: [Dog],
        startingFrom startLocation: CLLocationCoordinate2D? = nil,
        strategy: Strategy = .bruteForce
    ) -> OptimizedRoute {
        let pickups = dogs.map { Pickup(from: $0) }

        // Auto-select strategy based on count (brute-force for ≤8 dogs only)
        let selectedStrategy: Strategy
        if dogs.count > 8 {
            selectedStrategy = .nearestNeighbor  // Fast approximation for large groups (9+ dogs)
        } else {
            selectedStrategy = strategy
        }

        return optimizeRoute(for: pickups, startingFrom: startLocation, strategy: selectedStrategy)
    }

    // MARK: - Multi-Hike Optimization

    /// Result of multi-hike optimization analysis
    struct MultiHikeOptimizationResult {
        let currentDistance: CLLocationDistance
        let potentialDistance: CLLocationDistance
        let improvement: CLLocationDistance
        let improvementPercent: Double
        let suggestedGroups: [[Dog]]
        let shouldRegroup: Bool  // Recommend if >10% improvement
    }

    /// Analyze multi-hike distribution and suggest regrouping if beneficial
    ///
    /// Compares current hike groupings with optimal geographic clustering.
    /// Recommends regrouping if total distance could be reduced by >10%.
    ///
    /// - Parameters:
    ///   - hikes: Current hikes for the day
    ///   - allDogs: All participating dogs
    /// - Returns: Analysis result with improvement metrics
    static func optimizeMultiHikeDistribution(
        hikes: [DailyHike],
        allDogs: [Dog]
    ) -> MultiHikeOptimizationResult {
        // Calculate current total distance
        let currentTotalDistance = hikes.reduce(0) { $0 + $1.totalDistance }

        // Get all scheduled dogs from hikes
        let scheduledDogIds = Set(hikes.flatMap { $0.participations.map { $0.dogId } })
        let allScheduledDogs = allDogs.filter { scheduledDogIds.contains($0.id) }

        // Re-cluster all dogs geographically
        let clustered = HikeClusterer.clusterDogs(allScheduledDogs)

        // Calculate potential total distance with optimal clustering
        var potentialTotalDistance: Double = 0
        for group in clustered.groups {
            let route = optimizeRoute(for: group)
            potentialTotalDistance += route.totalDistance
        }

        let improvement = currentTotalDistance - potentialTotalDistance
        let improvementPercent = currentTotalDistance > 0 ? (improvement / currentTotalDistance) * 100 : 0

        return MultiHikeOptimizationResult(
            currentDistance: currentTotalDistance,
            potentialDistance: potentialTotalDistance,
            improvement: improvement,
            improvementPercent: improvementPercent,
            suggestedGroups: clustered.groups,
            shouldRegroup: improvementPercent > 10  // Recommend if >10% improvement
        )
    }

    /// Optimize route respecting manual ordering flag
    ///
    /// If manual ordering is enabled, calculates distance without changing order.
    /// Otherwise, runs normal optimization.
    ///
    /// - Parameters:
    ///   - dogs: Dogs to route
    ///   - manuallyOrdered: Whether dogs have been manually ordered by user
    /// - Returns: Optimized route (or current order with distance calculation)
    static func optimizeRouteRespectingManualOrder(
        for dogs: [Dog],
        manuallyOrdered: Bool
    ) -> OptimizedRoute {
        if manuallyOrdered {
            // Just calculate distance, don't reorder
            let pickups = dogs.map { Pickup(from: $0) }
            let distance = calculateTotalDistance(for: pickups, startingFrom: nil)
            return OptimizedRoute(
                pickups: pickups,
                totalDistance: distance,
                strategy: .bruteForce  // Mark as if optimized (it was, manually)
            )
        } else {
            // Normal optimization
            return optimizeRoute(for: dogs)
        }
    }

    // MARK: - Private Algorithms

    /// Nearest-neighbor greedy algorithm (fast, ~85% optimal)
    private static func nearestNeighborRoute(
        for pickups: [Pickup],
        startingFrom startLocation: CLLocationCoordinate2D?
    ) -> OptimizedRoute {
        var remaining = pickups
        var route: [Pickup] = []
        var totalDistance: CLLocationDistance = 0
        var currentLocation = startLocation ?? pickups.first!.coordinate

        while !remaining.isEmpty {
            // Find nearest unvisited pickup
            let (nearestIndex, distance) = findNearest(to: currentLocation, in: remaining)
            let nearest = remaining.remove(at: nearestIndex)

            route.append(nearest)
            totalDistance += distance
            currentLocation = nearest.coordinate
        }

        return OptimizedRoute(pickups: route, totalDistance: totalDistance, strategy: .nearestNeighbor)
    }

    /// Brute-force optimization (tries all permutations, finds optimal route)
    /// Efficient enough for ≤8 dogs (8! = 40,320 permutations ~100ms)
    private static func bruteForceRoute(
        for pickups: [Pickup],
        startingFrom startLocation: CLLocationCoordinate2D?
    ) -> OptimizedRoute {
        // For larger groups, fall back to nearest-neighbor
        if pickups.count > 8 {
            return nearestNeighborRoute(for: pickups, startingFrom: startLocation)
        }

        var bestRoute: [Pickup] = pickups
        var bestDistance: CLLocationDistance = .infinity

        // Generate all permutations and find the shortest route
        for permutation in permutations(of: pickups) {
            let distance = calculateTotalDistance(
                for: permutation,
                startingFrom: startLocation
            )

            if distance < bestDistance {
                bestDistance = distance
                bestRoute = permutation
            }
        }

        return OptimizedRoute(pickups: bestRoute, totalDistance: bestDistance, strategy: .bruteForce)
    }

    // MARK: - Helper Functions

    /// Calculate total distance for a route
    private static func calculateTotalDistance(
        for pickups: [Pickup],
        startingFrom startLocation: CLLocationCoordinate2D?
    ) -> CLLocationDistance {
        guard !pickups.isEmpty else { return 0 }

        var totalDistance: CLLocationDistance = 0
        var currentLocation = startLocation ?? pickups.first!.coordinate

        for pickup in pickups {
            totalDistance += distance(from: currentLocation, to: pickup.coordinate)
            currentLocation = pickup.coordinate
        }

        return totalDistance
    }

    /// Find the nearest pickup to a given location
    private static func findNearest(
        to location: CLLocationCoordinate2D,
        in pickups: [Pickup]
    ) -> (index: Int, distance: CLLocationDistance) {
        var nearestIndex = 0
        var nearestDistance: CLLocationDistance = .infinity

        for (index, pickup) in pickups.enumerated() {
            let dist = distance(from: location, to: pickup.coordinate)
            if dist < nearestDistance {
                nearestDistance = dist
                nearestIndex = index
            }
        }

        return (nearestIndex, nearestDistance)
    }

    /// Calculate straight-line distance between two coordinates
    private static func distance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Check if a coordinate is valid (not 0,0 or out of bounds)
    private static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude != 0 || coordinate.longitude != 0
    }

    /// Generate all permutations of an array (Heap's algorithm)
    private static func permutations<T>(of array: [T]) -> [[T]] {
        var result: [[T]] = []
        var array = array

        func heapPermutation(_ n: Int) {
            if n == 1 {
                result.append(array)
                return
            }

            for i in 0..<n {
                heapPermutation(n - 1)
                if n % 2 == 1 {
                    array.swapAt(0, n - 1)
                } else {
                    array.swapAt(i, n - 1)
                }
            }
        }

        heapPermutation(array.count)
        return result
    }
}

// MARK: - Extensions

extension CLLocationDistance {
    /// Format distance in kilometers with 1 decimal place
    var kilometersFormatted: String {
        String(format: "%.1f km", self / 1000)
    }
}
