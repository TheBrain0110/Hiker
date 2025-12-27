//
//  HikeClusterer.swift
//  Hiker
//
//  Created by Claude on 2025-12-26.
//

import Foundation
import CoreLocation

/// Geographic clustering utility for grouping dogs into optimal hike groups
///
/// Uses K-Means clustering with capacity constraints to minimize travel distance
/// while respecting soft capacity limits (default 8 dogs per hike).
struct HikeClusterer {

    // MARK: - Public API

    /// Result of clustering operation
    struct ClusterResult {
        /// Groups of dogs, ordered by cluster size (largest first)
        var groups: [[Dog]]

        /// Method used for clustering ("auto_geographic", "single_group")
        let method: String

        /// Average distance within clusters (lower is better)
        let avgDistanceWithinCluster: Double

        /// Total distance between cluster centroids
        let totalCrossClusterDistance: Double
    }

    /// Cluster dogs into optimal hike groups using geographic K-Means
    ///
    /// - Parameters:
    ///   - dogs: Dogs to cluster
    ///   - maxDogsPerHike: Soft capacity limit per cluster (default 8)
    ///   - maxClusters: Hard limit on number of clusters (default 2 for production)
    ///   - allowOverflow: If true, allows clusters to exceed capacity when needed
    /// - Returns: ClusterResult with optimal groupings
    static func clusterDogs(
        _ dogs: [Dog],
        maxDogsPerHike: Int = 8,
        maxClusters: Int = 2,
        allowOverflow: Bool = true
    ) -> ClusterResult {
        // Filter dogs with valid locations
        let dogsWithLocation = dogs.filter { $0.location != nil }
        let dogsWithoutLocation = dogs.filter { $0.location == nil }

        // Edge case: No dogs or all dogs fit in one hike
        if dogsWithLocation.count <= maxDogsPerHike {
            return ClusterResult(
                groups: dogsWithLocation.isEmpty ? [] : [dogsWithLocation + dogsWithoutLocation],
                method: "single_group",
                avgDistanceWithinCluster: 0,
                totalCrossClusterDistance: 0
            )
        }

        // Determine range of cluster counts to try
        let minClusters = Int(ceil(Double(dogsWithLocation.count) / Double(maxDogsPerHike)))
        let actualMaxClusters = min(maxClusters, dogsWithLocation.count)

        // Clamp minClusters to not exceed actualMaxClusters (handles hard cap with overflow)
        let startK = min(minClusters, actualMaxClusters)
        // For 17 dogs with maxClusters=2: startK = min(3, 2) = 2, actualMaxClusters = 2

        // Try different cluster counts and find best
        var bestResult: ClusterResult? = nil
        var bestScore: Double = .infinity

        for k in startK...actualMaxClusters {
            // Use flexible soft capacity that allows geographic clustering while preventing extreme imbalance
            // For 17 dogs, 2 clusters: maxDogsPerHike (8) + 3 = 11 per cluster
            // This allows 6-11, 7-10, 8-9, etc. - geographic clustering takes priority unless very imbalanced
            let softCapacity = allowOverflow
                ? maxDogsPerHike + 3  // Allow up to 3 dogs over the 8-dog soft cap
                : maxDogsPerHike

            let result = runKMeans(
                dogs: dogsWithLocation,
                k: k,
                maxDogsPerCluster: softCapacity
            )

            let score = calculateScore(result)

            if score < bestScore {
                bestScore = score
                bestResult = result
            }
        }

        // Add dogs without locations to smallest cluster
        if var result = bestResult, !dogsWithoutLocation.isEmpty {
            if let smallestIndex = result.groups.enumerated().min(by: { $0.element.count < $1.element.count })?.offset {
                result.groups[smallestIndex].append(contentsOf: dogsWithoutLocation)
            }
            return result
        }

        return bestResult ?? ClusterResult(
            groups: [dogs],
            method: "fallback",
            avgDistanceWithinCluster: 0,
            totalCrossClusterDistance: 0
        )
    }

    // MARK: - K-Means Implementation

    /// Run K-Means clustering with capacity constraints
    private static func runKMeans(
        dogs: [Dog],
        k: Int,
        maxDogsPerCluster: Int
    ) -> ClusterResult {
        // Initialize centroids using K-Means++
        var centroids = initializeCentroidsKMeansPlusPlus(dogs: dogs, k: k)

        var assignments: [Int] = Array(repeating: 0, count: dogs.count)
        var converged = false
        var iterations = 0
        let maxIterations = 50

        while !converged && iterations < maxIterations {
            // Assignment step with capacity constraints
            let newAssignments = assignToNearestCentroidWithCapacity(
                dogs: dogs,
                centroids: centroids,
                maxCapacity: maxDogsPerCluster
            )

            // Update centroids
            centroids = updateCentroids(dogs: dogs, assignments: newAssignments, k: k)

            // Check convergence
            converged = (newAssignments == assignments)
            assignments = newAssignments
            iterations += 1
        }

        // Group dogs by cluster
        var groups: [[Dog]] = Array(repeating: [], count: k)
        for (index, dog) in dogs.enumerated() {
            groups[assignments[index]].append(dog)
        }

        // Remove empty clusters and sort by size (largest first)
        groups = groups.filter { !$0.isEmpty }.sorted { $0.count > $1.count }

        return ClusterResult(
            groups: groups,
            method: "auto_geographic",
            avgDistanceWithinCluster: calculateAvgWithinClusterDistance(groups),
            totalCrossClusterDistance: calculateCrossClusterDistance(groups)
        )
    }

    // MARK: - K-Means++ Initialization

    /// Initialize centroids using K-Means++ algorithm (spreads initial centroids)
    private static func initializeCentroidsKMeansPlusPlus(
        dogs: [Dog],
        k: Int
    ) -> [CLLocationCoordinate2D] {
        var centroids: [CLLocationCoordinate2D] = []

        // First centroid: random dog location
        guard let firstLocation = dogs.randomElement()?.location else {
            // Fallback: Halifax center
            return Array(repeating: CLLocationCoordinate2D(latitude: 44.65, longitude: -63.6), count: k)
        }
        centroids.append(firstLocation)

        // Remaining centroids: weighted by distance from existing centroids
        while centroids.count < k && centroids.count < dogs.count {
            var maxMinDistance: Double = 0
            var farthestDog: Dog? = nil

            for dog in dogs {
                guard let dogLocation = dog.location else { continue }

                // Find minimum distance to any existing centroid
                let minDistanceToExisting = centroids.map { centroid in
                    CLLocation(latitude: dogLocation.latitude, longitude: dogLocation.longitude)
                        .distance(from: CLLocation(latitude: centroid.latitude, longitude: centroid.longitude))
                }.min() ?? 0

                // Track dog with maximum minimum distance (farthest from all centroids)
                if minDistanceToExisting > maxMinDistance {
                    maxMinDistance = minDistanceToExisting
                    farthestDog = dog
                }
            }

            if let location = farthestDog?.location {
                centroids.append(location)
            } else {
                break
            }
        }

        return centroids
    }

    // MARK: - Assignment with Capacity Constraints

    /// Assign dogs to nearest centroid with capacity constraints
    private static func assignToNearestCentroidWithCapacity(
        dogs: [Dog],
        centroids: [CLLocationCoordinate2D],
        maxCapacity: Int
    ) -> [Int] {
        var assignments: [Int] = Array(repeating: -1, count: dogs.count)
        var clusterSizes: [Int] = Array(repeating: 0, count: centroids.count)

        // Calculate distances for all dog-centroid pairs
        var dogDistances: [(dogIndex: Int, clusterIndex: Int, distance: Double)] = []
        for (dogIndex, dog) in dogs.enumerated() {
            guard let dogLocation = dog.location else { continue }

            for (clusterIndex, centroid) in centroids.enumerated() {
                let distance = CLLocation(latitude: dogLocation.latitude, longitude: dogLocation.longitude)
                    .distance(from: CLLocation(latitude: centroid.latitude, longitude: centroid.longitude))

                dogDistances.append((dogIndex, clusterIndex, distance))
            }
        }

        // Sort by distance (assign closest first)
        dogDistances.sort { $0.distance < $1.distance }

        // Greedy assignment with capacity check
        for (dogIndex, clusterIndex, _) in dogDistances {
            // Skip if dog already assigned
            if assignments[dogIndex] != -1 { continue }

            // Assign if cluster has capacity
            if clusterSizes[clusterIndex] < maxCapacity {
                assignments[dogIndex] = clusterIndex
                clusterSizes[clusterIndex] += 1
            }
        }

        // Fallback: Assign any unassigned dogs to smallest cluster (overflow)
        for dogIndex in 0..<dogs.count {
            if assignments[dogIndex] == -1 {
                let smallestCluster = clusterSizes.enumerated().min(by: { $0.element < $1.element })!.offset
                assignments[dogIndex] = smallestCluster
                clusterSizes[smallestCluster] += 1
            }
        }

        return assignments
    }

    // MARK: - Centroid Updates

    /// Update centroids to mean position of assigned dogs
    private static func updateCentroids(
        dogs: [Dog],
        assignments: [Int],
        k: Int
    ) -> [CLLocationCoordinate2D] {
        var centroids: [CLLocationCoordinate2D] = []

        for clusterIndex in 0..<k {
            let dogsInCluster = dogs.enumerated()
                .filter { assignments[$0.offset] == clusterIndex }
                .compactMap { $0.element.location }

            if dogsInCluster.isEmpty {
                // Keep Halifax center if cluster is empty
                centroids.append(CLLocationCoordinate2D(latitude: 44.65, longitude: -63.6))
            } else {
                let avgLat = dogsInCluster.map { $0.latitude }.reduce(0, +) / Double(dogsInCluster.count)
                let avgLon = dogsInCluster.map { $0.longitude }.reduce(0, +) / Double(dogsInCluster.count)
                centroids.append(CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon))
            }
        }

        return centroids
    }

    // MARK: - Scoring and Metrics

    /// Calculate score for clustering result (lower is better)
    private static func calculateScore(_ result: ClusterResult) -> Double {
        // Score = weighted sum of within-cluster distance + penalty for imbalance
        let imbalancePenalty = calculateImbalancePenalty(result.groups)
        return result.avgDistanceWithinCluster + imbalancePenalty * 1000 // 1km penalty per dog imbalance
    }

    /// Calculate imbalance penalty (standard deviation of group sizes)
    private static func calculateImbalancePenalty(_ groups: [[Dog]]) -> Double {
        guard !groups.isEmpty else { return 0 }

        let sizes = groups.map { $0.count }
        let avgSize = Double(sizes.reduce(0, +)) / Double(groups.count)
        let variance = sizes.map { pow(Double($0) - avgSize, 2) }.reduce(0, +) / Double(groups.count)
        return sqrt(variance)
    }

    /// Calculate average distance within clusters
    private static func calculateAvgWithinClusterDistance(_ groups: [[Dog]]) -> Double {
        var totalDistance: Double = 0
        var pairCount = 0

        for group in groups {
            for i in 0..<group.count {
                for j in (i+1)..<group.count {
                    guard let loc1 = group[i].location, let loc2 = group[j].location else { continue }

                    let distance = CLLocation(latitude: loc1.latitude, longitude: loc1.longitude)
                        .distance(from: CLLocation(latitude: loc2.latitude, longitude: loc2.longitude))

                    totalDistance += distance
                    pairCount += 1
                }
            }
        }

        return pairCount > 0 ? totalDistance / Double(pairCount) : 0
    }

    /// Calculate total distance between cluster centroids
    private static func calculateCrossClusterDistance(_ groups: [[Dog]]) -> Double {
        guard groups.count > 1 else { return 0 }

        // Calculate centroids
        var centroids: [CLLocationCoordinate2D] = []
        for group in groups {
            let locations = group.compactMap { $0.location }
            guard !locations.isEmpty else { continue }

            let avgLat = locations.map { $0.latitude }.reduce(0, +) / Double(locations.count)
            let avgLon = locations.map { $0.longitude }.reduce(0, +) / Double(locations.count)
            centroids.append(CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon))
        }

        // Calculate total distance between all centroid pairs
        var totalDistance: Double = 0
        for i in 0..<centroids.count {
            for j in (i+1)..<centroids.count {
                let distance = CLLocation(
                    latitude: centroids[i].latitude,
                    longitude: centroids[i].longitude
                ).distance(from: CLLocation(
                    latitude: centroids[j].latitude,
                    longitude: centroids[j].longitude
                ))
                totalDistance += distance
            }
        }

        return totalDistance
    }
}
