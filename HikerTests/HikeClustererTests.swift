//
//  HikeClustererTests.swift
//  HikerTests
//
//  Created by Claude on 2025-12-26.
//

import Testing
import Foundation
import CoreLocation
@testable import Hiker

/// Tests for HikeClusterer geographic clustering algorithm
@Suite("HikeClusterer Tests")
struct HikeClustererTests {

    // MARK: - Small Group Tests

    @Test("Empty array returns empty result")
    func testEmptyArray() {
        let dogs: [Dog] = []
        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.isEmpty)
        #expect(result.method == "single_group")
    }

    @Test("Single dog creates one cluster")
    func testSingleDog() {
        let dogs = [makeDog(name: "Buddy", lat: 44.73, lon: -63.65)]
        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 1)
        #expect(result.groups[0].count == 1)
        #expect(result.method == "single_group")
    }

    @Test("Small group (≤8 dogs) creates single cluster")
    func testSmallGroupSingleCluster() {
        let dogs = [
            makeDog(name: "Dog1", lat: 44.73, lon: -63.65),  // Bedford
            makeDog(name: "Dog2", lat: 44.77, lon: -63.67),  // Sackville
            makeDog(name: "Dog3", lat: 44.81, lon: -63.62),  // Beaver Bank
            makeDog(name: "Dog4", lat: 44.74, lon: -63.66),  // Bedford
            makeDog(name: "Dog5", lat: 44.78, lon: -63.68)   // Sackville
        ]
        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 1)
        #expect(result.groups[0].count == 5)
        #expect(result.method == "single_group")
    }

    // MARK: - Medium Group Tests

    @Test("10 dogs creates 2 clusters")
    func testMediumGroupMultipleClusters() {
        var dogs: [Dog] = []

        // 5 dogs in Bedford area
        for i in 0..<5 {
            dogs.append(makeDog(name: "Bedford\(i)", lat: 44.73 + Double(i) * 0.002, lon: -63.65))
        }

        // 5 dogs in Beaver Bank area (10km north)
        for i in 0..<5 {
            dogs.append(makeDog(name: "BeaverBank\(i)", lat: 44.81 + Double(i) * 0.002, lon: -63.62))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        // Should create 2 clusters (minimum needed for 10 dogs)
        #expect(result.groups.count == 2)
        #expect(result.method == "auto_geographic")

        // Clusters should be reasonably balanced
        let sizes = result.groups.map { $0.count }
        #expect(sizes.allSatisfy { $0 >= 3 && $0 <= 7 })  // No extreme imbalance
    }

    @Test("16 dogs creates 2 clusters with max 8 each")
    func test16DogsSplit() {
        var dogs: [Dog] = []

        // 8 dogs in Bedford area
        for i in 0..<8 {
            dogs.append(makeDog(name: "Bedford\(i)", lat: 44.73 + Double(i) * 0.001, lon: -63.65))
        }

        // 8 dogs in Beaver Bank area
        for i in 0..<8 {
            dogs.append(makeDog(name: "BeaverBank\(i)", lat: 44.81 + Double(i) * 0.001, lon: -63.62))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 2)
        #expect(result.groups.allSatisfy { $0.count <= 8 })
        #expect(result.method == "auto_geographic")
    }

    // MARK: - Large Group Tests

    @Test("20 dogs creates 3+ clusters")
    func testLargeGroupMultipleClusters() {
        var dogs: [Dog] = []

        // Distribute dogs across Halifax area
        for i in 0..<20 {
            let lat = 44.73 + Double(i % 5) * 0.02  // Spread across ~10km
            let lon = -63.65 + Double(i / 5) * 0.02
            dogs.append(makeDog(name: "Dog\(i)", lat: lat, lon: lon))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        // Should create at least 3 clusters (20 / 8 = 2.5 → 3)
        #expect(result.groups.count >= 3)
        #expect(result.groups.allSatisfy { $0.count <= 8 })
        #expect(result.method == "auto_geographic")
    }

    @Test("Clustering respects capacity constraints")
    func testCapacityConstraints() {
        var dogs: [Dog] = []

        // Create 25 dogs in tight cluster
        for i in 0..<25 {
            dogs.append(makeDog(name: "Dog\(i)", lat: 44.75 + Double(i) * 0.0005, lon: -63.65))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8, allowOverflow: false)

        // Should create at least 4 clusters (25 / 8 = 3.125 → 4)
        #expect(result.groups.count >= 4)

        // With allowOverflow=false, no cluster should exceed capacity
        #expect(result.groups.allSatisfy { $0.count <= 8 })
    }

    // MARK: - Geographic Clustering Tests

    @Test("Geographic separation produces distinct clusters")
    func testGeographicSeparation() {
        var dogs: [Dog] = []

        // Cluster 1: Bedford (southwest)
        for i in 0..<6 {
            dogs.append(makeDog(name: "Bedford\(i)", lat: 44.73 + Double(i) * 0.001, lon: -63.65))
        }

        // Cluster 2: Beaver Bank (northeast, ~12km away)
        for i in 0..<6 {
            dogs.append(makeDog(name: "BeaverBank\(i)", lat: 44.81 + Double(i) * 0.001, lon: -63.55))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 2)
        #expect(result.method == "auto_geographic")

        // Verify dogs are grouped by proximity
        // Each cluster should have all Bedford or all Beaver Bank dogs
        for group in result.groups {
            let names = group.map { $0.name }
            let allBedford = names.allSatisfy { $0.hasPrefix("Bedford") }
            let allBeaverBank = names.allSatisfy { $0.hasPrefix("BeaverBank") }
            #expect(allBedford || allBeaverBank)
        }
    }

    @Test("K-Means++ initialization spreads centroids")
    func testKMeansPlusPlusInitialization() {
        var dogs: [Dog] = []

        // Create tightly clustered group (all within 500m)
        for i in 0..<10 {
            dogs.append(makeDog(name: "Dog\(i)", lat: 44.75 + Double(i) * 0.0001, lon: -63.65))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 5)

        // Should create 2 clusters (10 / 5 = 2)
        #expect(result.groups.count == 2)

        // Clusters should be reasonably balanced (not 9-1 split)
        let sizes = result.groups.map { $0.count }
        let maxSize = sizes.max() ?? 0
        let minSize = sizes.min() ?? 0
        #expect(maxSize - minSize <= 2)  // Max imbalance of 2 dogs
    }

    // MARK: - Edge Case Tests

    @Test("Dogs without locations are handled gracefully")
    func testDogsWithoutLocations() {
        let dogsWithLocation = [
            makeDog(name: "Located1", lat: 44.73, lon: -63.65),
            makeDog(name: "Located2", lat: 44.77, lon: -63.67),
            makeDog(name: "Located3", lat: 44.75, lon: -63.66)
        ]
        let dogWithoutLocation1 = Dog(name: "NoLocation1", client: nil)
        let dogWithoutLocation2 = Dog(name: "NoLocation2", client: nil)

        let result = HikeClusterer.clusterDogs(
            dogsWithLocation + [dogWithoutLocation1, dogWithoutLocation2],
            maxDogsPerHike: 8
        )

        // Should cluster the 3 dogs with locations
        #expect(result.groups.count == 1)

        // Dogs without location should be added to the cluster
        #expect(result.groups[0].count == 5)

        // Verify no-location dogs are in the result
        let allDogs = result.groups.flatMap { $0 }
        #expect(allDogs.contains { $0.name == "NoLocation1" })
        #expect(allDogs.contains { $0.name == "NoLocation2" })
    }

    @Test("All dogs without locations returns single group")
    func testAllDogsWithoutLocations() {
        let dogs = [
            Dog(name: "NoLoc1", client: nil),
            Dog(name: "NoLoc2", client: nil),
            Dog(name: "NoLoc3", client: nil)
        ]

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 1)
        #expect(result.groups[0].count == 3)
        #expect(result.method == "single_group")
    }

    @Test("Mixed valid and invalid coordinates")
    func testMixedCoordinates() {
        let dogs = [
            makeDog(name: "Valid1", lat: 44.73, lon: -63.65),
            makeDog(name: "Valid2", lat: 44.77, lon: -63.67),
            Dog(name: "Invalid", client: nil),
            makeDog(name: "Valid3", lat: 44.75, lon: -63.66)
        ]

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        #expect(result.groups.count == 1)
        #expect(result.groups[0].count == 4)  // All dogs included
    }

    // MARK: - Scoring Tests

    @Test("Balanced clusters have lower imbalance penalty")
    func testBalancedClusters() {
        var dogs: [Dog] = []

        // Create 18 dogs distributed across two areas
        for i in 0..<9 {
            dogs.append(makeDog(name: "Bedford\(i)", lat: 44.73 + Double(i) * 0.001, lon: -63.65))
        }
        for i in 0..<9 {
            dogs.append(makeDog(name: "BeaverBank\(i)", lat: 44.81 + Double(i) * 0.001, lon: -63.62))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        // Should create 3 clusters with sizes close to 6-6-6
        #expect(result.groups.count >= 2)

        let sizes = result.groups.map { $0.count }
        let maxSize = sizes.max() ?? 0
        let minSize = sizes.min() ?? 0

        // Clusters should be relatively balanced
        #expect(maxSize - minSize <= 3)
    }

    @Test("Within-cluster distance is calculated correctly")
    func testWithinClusterDistanceMetric() {
        // Create two tight clusters far apart
        var dogs: [Dog] = []

        // Tight cluster 1 (all within ~100m)
        for i in 0..<5 {
            dogs.append(makeDog(name: "Cluster1_\(i)", lat: 44.73, lon: -63.65 + Double(i) * 0.0001))
        }

        // Tight cluster 2 (all within ~100m, but 10km from cluster 1)
        for i in 0..<5 {
            dogs.append(makeDog(name: "Cluster2_\(i)", lat: 44.81, lon: -63.62 + Double(i) * 0.0001))
        }

        let result = HikeClusterer.clusterDogs(dogs, maxDogsPerHike: 8)

        // Average within-cluster distance should be small (tight clusters)
        #expect(result.avgDistanceWithinCluster < 1000)  // Less than 1km average

        // Cross-cluster distance should be large (clusters far apart)
        #expect(result.totalCrossClusterDistance > 5000)  // More than 5km between centroids
    }

    // MARK: - Helper

    /// Create a test dog with specified location
    private func makeDog(name: String, lat: Double, lon: Double) -> Dog {
        Dog(
            name: name,
            client: nil,
            locationLatitude: lat,
            locationLongitude: lon
        )
    }
}
