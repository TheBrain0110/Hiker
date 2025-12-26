//
//  DailyHikeManager.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//  Refactored for unified DailyHike model on 12/25/25.
//

import Foundation
import SwiftData
import CoreLocation

/// Manages daily hike schedules with lazy persistence.
/// Computes which dogs should be picked up based on their regular schedules and daily overrides,
/// then caches the result in a persistent DailyHike model.
@MainActor
class DailyHikeManager {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Get or create a DailyHike for a specific date and hike number.
    /// Returns existing persistent hike if found, otherwise computes and persists a new one.
    func getOrCreateDailyHike(for date: Date, hikeNumber: Int) -> DailyHike? {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Check for existing hike
        if let existing = fetchExistingHike(date: normalizedDate, hikeNumber: hikeNumber) {
            return existing
        }

        // Compute schedule from rules
        guard let dayOfWeek = date.dayOfWeek else {
            // Weekend - no regular hikes
            return nil
        }

        let scheduledDogs = getScheduledDogs(for: date, dayOfWeek: dayOfWeek)
        let groups = groupIntoHikes(scheduledDogs)

        // Check if this hike number has dogs
        guard hikeNumber <= groups.count, !groups[hikeNumber - 1].isEmpty else {
            return nil
        }

        // Create and persist new DailyHike
        let hike = createDailyHike(
            date: normalizedDate,
            hikeNumber: hikeNumber,
            dogs: groups[hikeNumber - 1]
        )

        modelContext.insert(hike)
        return hike
    }

    /// Get all DailyHikes for a specific date (both hike 1 and 2 if they exist)
    func getDailyHikes(for date: Date) -> [DailyHike] {
        var hikes: [DailyHike] = []
        if let hike1 = getOrCreateDailyHike(for: date, hikeNumber: 1) {
            hikes.append(hike1)
        }
        if let hike2 = getOrCreateDailyHike(for: date, hikeNumber: 2) {
            hikes.append(hike2)
        }
        return hikes
    }

    /// Reset a DailyHike by deleting it (caller should call getOrCreateDailyHike to regenerate)
    func resetDailyHike(_ hike: DailyHike) {
        modelContext.delete(hike)
    }

    /// Mark future DailyHikes as stale when a dog's schedule changes
    func markAffectedHikesStale(for dogId: UUID, after date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Find all participations for this dog
        let descriptor = FetchDescriptor<HikeParticipation>(
            predicate: #Predicate { $0.dogId == dogId }
        )
        guard let participations = try? modelContext.fetch(descriptor) else { return }

        for participation in participations {
            if let hike = participation.dailyHike,
               hike.date >= normalizedDate,
               hike.completedAt == nil {
                hike.staleReason = .scheduleChanged
                hike.lastModifiedAt = Date()
            }
        }
    }

    /// Fetch all DailyHikes for a date (without creating new ones)
    func fetchExistingHikes(for date: Date) -> [DailyHike] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!

        let descriptor = FetchDescriptor<DailyHike>(
            predicate: #Predicate { $0.date >= normalizedDate && $0.date < nextDay },
            sortBy: [SortDescriptor(\.hikeNumber)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private Helpers

    /// Fetch existing hike for a specific date and hike number
    private func fetchExistingHike(date: Date, hikeNumber: Int) -> DailyHike? {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!

        let descriptor = FetchDescriptor<DailyHike>(
            predicate: #Predicate {
                $0.date >= date &&
                $0.date < nextDay &&
                $0.hikeNumber == hikeNumber
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    /// Create a new DailyHike with optimized route and participation records
    private func createDailyHike(date: Date, hikeNumber: Int, dogs: [Dog]) -> DailyHike {
        // Optimize the pickup route
        let optimizedRoute = RouteOptimizer.optimizeRoute(for: dogs)

        // Order dogs by optimized route
        let orderedDogs = optimizedRoute.pickups.compactMap { pickup in
            dogs.first { $0.id == pickup.id }
        }

        // Build route coordinates
        let routeCoordinates = orderedDogs.compactMap { $0.location }

        // Suggest a trail
        let hikingLocations = fetchHikingLocations()
        let suggestedTrail = suggestTrail(
            for: orderedDogs,
            routeCoordinates: routeCoordinates,
            hikingLocations: hikingLocations
        )

        // Determine override status for each dog
        let overridesForDate = fetchOverrides(for: date)
        let overrideMap = Dictionary(uniqueKeysWithValues:
            overridesForDate.map { ($0.dogId, $0.type) }
        )

        // Create the hike
        let now = Date()
        let dailyHike = DailyHike(
            date: date,
            hikeNumber: hikeNumber,
            routeLatitudes: routeCoordinates.map { $0.latitude },
            routeLongitudes: routeCoordinates.map { $0.longitude },
            totalDistance: optimizedRoute.totalDistance,
            selectedTrailId: suggestedTrail?.id,
            trailName: suggestedTrail?.name,
            createdAt: now,
            lastModifiedAt: now
        )

        // Create participation records
        for (index, dog) in orderedDogs.enumerated() {
            let wasAdded = overrideMap[dog.id] == .isPresent

            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: index + 1,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate,
                isConfirmed: false,  // Not yet confirmed (planned hike)
                wasAddedViaOverride: wasAdded
            )
            participation.dailyHike = dailyHike
        }

        return dailyHike
    }

    /// Get all dogs that should be scheduled for a specific date
    private func getScheduledDogs(for date: Date, dayOfWeek: DayOfWeek) -> [Dog] {
        // 1. Fetch all active dogs
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.name)]
        )
        guard let allDogs = try? modelContext.fetch(descriptor) else { return [] }

        // 2. Fetch all Overrides for this date
        let overridesForDate = fetchOverrides(for: date)

        // Map DogID -> OverrideType
        let overrideMap: [UUID: OverrideType] = overridesForDate.reduce(into: [:]) { dict, override in
            dict[override.dogId] = override.type
        }

        // 3. Filter Logic
        return allDogs.filter { dog in
            if let type = overrideMap[dog.id] {
                // If there is an override, follow it
                return type == .isPresent
            } else {
                // If no override, follow default schedule
                return dog.isScheduledOn(dayOfWeek)
            }
        }
    }

    /// Fetch overrides for a specific date
    private func fetchOverrides(for date: Date) -> [ScheduleOverride] {
        let targetStart = Calendar.current.startOfDay(for: date)
        let targetEnd = Calendar.current.date(byAdding: .day, value: 1, to: targetStart)!

        let descriptor = FetchDescriptor<ScheduleOverride>(
            predicate: #Predicate { $0.date >= targetStart && $0.date < targetEnd }
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Group dogs into hikes (max 8 per hike, 2 hikes max)
    private func groupIntoHikes(_ dogs: [Dog]) -> [[Dog]] {
        let maxDogsPerHike = 8
        let maxHikes = 2

        // If 8 or fewer dogs, one hike
        if dogs.count <= maxDogsPerHike {
            return dogs.isEmpty ? [] : [dogs]
        }

        // If more than 8 but less than or equal to 16, split into two balanced hikes
        if dogs.count <= maxDogsPerHike * maxHikes {
            let midpoint = dogs.count / 2
            let hike1 = Array(dogs[..<midpoint])
            let hike2 = Array(dogs[midpoint...])
            return [hike1, hike2]
        }

        // If more than 16, take first 16 and split evenly
        let limitedDogs = Array(dogs.prefix(maxDogsPerHike * maxHikes))
        let midpoint = limitedDogs.count / 2
        let hike1 = Array(limitedDogs[..<midpoint])
        let hike2 = Array(limitedDogs[midpoint...])
        return [hike1, hike2]
    }

    /// Suggest a hiking trail based on the last pickup location
    private func suggestTrail(
        for dogs: [Dog],
        routeCoordinates: [CLLocationCoordinate2D],
        hikingLocations: [HikingLocation]
    ) -> HikingLocation? {
        guard !hikingLocations.isEmpty else { return nil }
        guard let lastPickup = routeCoordinates.last else {
            return hikingLocations.first
        }

        // Find the closest trail to the last pickup
        let lastLocation = CLLocation(
            latitude: lastPickup.latitude,
            longitude: lastPickup.longitude
        )

        let trailWithDistances = hikingLocations.map { trail -> (trail: HikingLocation, distance: CLLocationDistance) in
            let trailLocation = CLLocation(
                latitude: trail.latitude,
                longitude: trail.longitude
            )
            let distance = lastLocation.distance(from: trailLocation)
            return (trail, distance)
        }

        return trailWithDistances.min(by: { $0.distance < $1.distance })?.trail
    }

    /// Fetch all active hiking locations
    private func fetchHikingLocations() -> [HikingLocation] {
        let descriptor = FetchDescriptor<HikingLocation>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.name)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
