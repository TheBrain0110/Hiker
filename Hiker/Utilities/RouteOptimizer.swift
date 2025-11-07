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
        return optimizeRoute(for: pickups, startingFrom: startLocation, strategy: strategy)
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
    /// Efficient enough for ≤8 dogs (8! = 40,320 permutations)
    private static func bruteForceRoute(
        for pickups: [Pickup],
        startingFrom startLocation: CLLocationCoordinate2D?
    ) -> OptimizedRoute {
        // For larger groups, fall back to nearest-neighbor
        if pickups.count > 10 {
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
