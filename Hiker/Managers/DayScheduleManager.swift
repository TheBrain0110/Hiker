//
//  DayScheduleManager.swift
//  Hiker
//
//  Created on 12/26/25.
//  Business logic for day schedule manipulation
//

import Foundation
import SwiftData
import CoreLocation

/// Manages schedule manipulation logic for a specific day
/// Handles dog add/remove with override state machine, route optimization, and schedule resets
@MainActor
class DayScheduleManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Dog Management

    /// Add dog to first available planned hike with override handling
    ///
    /// Override State Machine:
    /// - If override exists (likely .isAbsent) → Delete it to revert to regular schedule
    /// - If no override and NOT in regular schedule → Create .isPresent override
    /// - If no override and in regular schedule → Do nothing (already scheduled)
    func addDog(
        _ dog: Dog,
        to plannedHikes: [DailyHike],
        on date: Date,
        existingOverrides: [ScheduleOverride]
    ) {
        // Check if there's an existing override
        let hasExistingOverride = existingOverrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.dogId == dog.id
        })

        if let existing = hasExistingOverride {
            // Override exists (likely .isAbsent) - delete it to revert to regular schedule
            modelContext.delete(existing)
        } else {
            // No override exists, check if dog is in regular schedule for this day
            let dayOfWeek = date.dayOfWeek
            let isInRegularSchedule = dayOfWeek.map { dog.regularSchedule.contains($0) } ?? false

            if !isInRegularSchedule {
                // Not in regular schedule, so create .isPresent override
                let override = ScheduleOverride(dogId: dog.id, date: date, type: .isPresent)
                modelContext.insert(override)
            }
        }

        // Add participation to smallest planned hike (no hard limit)
        if let targetHike = plannedHikes.min(by: { $0.participations.count < $1.participations.count }) {
            let nextOrder = (targetHike.participations.map { $0.pickupOrder }.max() ?? 0) + 1
            let wasAddedViaOverride = hasExistingOverride == nil &&
                (date.dayOfWeek.map { !dog.regularSchedule.contains($0) } ?? true)

            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: nextOrder,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate,
                wasAddedViaOverride: wasAddedViaOverride
            )
            participation.dailyHike = targetHike
            targetHike.lastModifiedAt = Date()
        }
    }

    /// Remove dog from hike with override handling
    ///
    /// Override State Machine:
    /// - If .isPresent override exists → Delete it (revert to not scheduled)
    /// - If .isAbsent override exists → Do nothing (already absent)
    /// - If no override → Create .isAbsent override (block regular schedule)
    func removeDog(
        _ dogId: UUID,
        from hike: DailyHike,
        on date: Date,
        activeDogs: [Dog],
        existingOverrides: [ScheduleOverride]
    ) {
        guard let dog = activeDogs.first(where: { $0.id == dogId }) else { return }

        // Check if there's an existing override
        if let existing = existingOverrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.dogId == dog.id
        }) {
            if existing.type == .isPresent {
                // Was added manually, so just delete the override
                modelContext.delete(existing)
            } else {
                // Already has .isAbsent, do nothing
            }
        } else {
            // Dog is here from regular schedule, create .isAbsent override
            let override = ScheduleOverride(dogId: dog.id, date: date, type: .isAbsent)
            modelContext.insert(override)
        }

        // Remove dog's participation from the hike
        if let participation = hike.participations.first(where: { $0.dogId == dogId }) {
            modelContext.delete(participation)
        }

        hike.lastModifiedAt = Date()
    }

    // MARK: - Route Operations

    /// Re-optimize the pickup route for current dogs only (dog list doesn't change)
    func recalculateRoute(for hike: DailyHike) {
        // Get current dogs from participations
        let dogIds = hike.participations.map { $0.dogId }
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { dog in dogIds.contains(dog.id) }
        )
        guard let dogs = try? modelContext.fetch(descriptor), !dogs.isEmpty else {
            hike.lastModifiedAt = Date()
            return
        }

        // Re-run route optimizer
        let optimizedRoute = RouteOptimizer.optimizeRoute(for: dogs)

        // Update participation pickup orders
        for (index, pickup) in optimizedRoute.pickups.enumerated() {
            if let participation = hike.participations.first(where: { $0.dogId == pickup.id }) {
                participation.pickupOrder = index + 1
                // Update pickup location in case it changed
                if let dog = dogs.first(where: { $0.id == pickup.id }) {
                    participation.pickupLatitude = dog.locationLatitude
                    participation.pickupLongitude = dog.locationLongitude
                    participation.pickupAddress = dog.locationAddress
                }
            }
        }

        // Update route coordinates
        let routeCoordinates = optimizedRoute.pickups.compactMap { pickup in
            dogs.first { $0.id == pickup.id }?.location
        }
        hike.route = routeCoordinates
        hike.totalDistance = optimizedRoute.totalDistance
        hike.lastModifiedAt = Date()
    }

    /// Optimize all routes for a day (called when exiting edit mode)
    func optimizeAllRoutesForDay(_ date: Date, plannedHikes: [DailyHike]) {
        for hike in plannedHikes {
            recalculateRoute(for: hike)
        }
    }

    /// Sync dog list with current schedule + overrides, then optimize route
    func applyScheduleChanges(for hike: DailyHike) {
        let dailyHikeManager = DailyHikeManager(modelContext: modelContext)
        let date = hike.date
        let hikeNumber = hike.hikeNumber

        // Delete the current hike and regenerate with current schedule + overrides
        dailyHikeManager.resetDailyHike(hike)

        // Regenerate by loading hikes for this day
        // The getOrCreateDailyHike will create a fresh one based on current schedule + overrides
        _ = dailyHikeManager.getOrCreateDailyHike(for: date, hikeNumber: hikeNumber)
    }

    /// Clear all overrides for date and regenerate from regular schedule
    func resetToSchedule(
        for date: Date,
        existingHikes: [DailyHike],
        existingOverrides: [ScheduleOverride]
    ) {
        // Delete all overrides for this day
        let overridesForDay = existingOverrides.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        for override in overridesForDay {
            modelContext.delete(override)
        }

        // Delete all existing hikes for this day
        for hike in existingHikes {
            modelContext.delete(hike)
        }

        // Regenerate hikes from the regular schedule (no overrides)
        let dailyHikeManager = DailyHikeManager(modelContext: modelContext)
        _ = dailyHikeManager.getDailyHikes(for: date)
    }

    // MARK: - Override Helpers

    /// Check if dog has .isPresent override on date
    func hasAddedOverride(
        dogId: UUID,
        on date: Date,
        overrides: [ScheduleOverride]
    ) -> Bool {
        overrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: date) &&
            override.dogId == dogId &&
            override.type == .isPresent
        }
    }

    /// Check if dog has .isAbsent override on date
    func hasAbsentOverride(
        dogId: UUID,
        on date: Date,
        overrides: [ScheduleOverride]
    ) -> Bool {
        overrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: date) &&
            override.dogId == dogId &&
            override.type == .isAbsent
        }
    }

    // MARK: - Available Dogs

    /// Get dogs available to add (not in any planned hike)
    func getAvailableDogs(
        allActiveDogs: [Dog],
        plannedHikes: [DailyHike]
    ) -> [Dog] {
        let allScheduledDogIds = Set(plannedHikes.flatMap { $0.participations.map { $0.dogId } })
        return allActiveDogs.filter { !allScheduledDogIds.contains($0.id) && $0.isActive }
    }

    // MARK: - Drag-and-Drop Operations

    /// Move dog from one hike to another
    ///
    /// - Parameters:
    ///   - dogId: ID of dog to move
    ///   - sourceHike: Hike to remove dog from
    ///   - targetHike: Hike to add dog to
    func moveDog(
        _ dogId: UUID,
        from sourceHike: DailyHike,
        to targetHike: DailyHike
    ) {
        // Remove from source hike
        if let participation = sourceHike.participations.first(where: { $0.dogId == dogId }) {
            modelContext.delete(participation)
            sourceHike.lastModifiedAt = Date()
        }

        // Add to target hike
        let nextOrder = (targetHike.participations.map { $0.pickupOrder }.max() ?? 0) + 1
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { $0.id == dogId }
        )

        if let dog = try? modelContext.fetch(descriptor).first {
            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: nextOrder,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate,
                wasAddedViaOverride: false  // Inter-hike moves don't create overrides
            )
            participation.dailyHike = targetHike
            targetHike.lastModifiedAt = Date()
        }
    }

    /// Move dog from one hike to another at a specific position
    ///
    /// - Parameters:
    ///   - dogId: ID of dog to move
    ///   - sourceHike: Hike to remove dog from
    ///   - targetHike: Hike to add dog to
    ///   - targetPosition: Position to insert at (0-based index)
    func moveDog(
        _ dogId: UUID,
        from sourceHike: DailyHike,
        to targetHike: DailyHike,
        at targetPosition: Int
    ) {
        // First move the dog to the target hike (adds at end)
        moveDog(dogId, from: sourceHike, to: targetHike)

        // Then reorder to place at the target position
        var orderedDogIds = targetHike.orderedParticipations.map { $0.dogId }

        // Remove from current position (end) and insert at target position
        if let currentIndex = orderedDogIds.firstIndex(of: dogId) {
            orderedDogIds.remove(at: currentIndex)
            orderedDogIds.insert(dogId, at: min(targetPosition, orderedDogIds.count))

            // Update pickup orders
            for (index, participationDogId) in orderedDogIds.enumerated() {
                if let participation = targetHike.participations.first(where: { $0.dogId == participationDogId }) {
                    participation.pickupOrder = index + 1
                }
            }
        }
    }

    /// Reorder dogs within a hike (manual drag-to-reorder)
    ///
    /// - Parameters:
    ///   - hike: Hike to reorder
    ///   - orderedDogIds: New order of dog IDs
    func reorderDogs(
        in hike: DailyHike,
        orderedDogIds: [UUID]
    ) {
        // Update pickup orders to match new sequence
        for (index, dogId) in orderedDogIds.enumerated() {
            if let participation = hike.participations.first(where: { $0.dogId == dogId }) {
                participation.pickupOrder = index + 1
            }
        }

        // Mark as manually ordered (prevent auto-optimization from changing order)
        hike.hasManualRouteOrder = true

        // Recalculate route distance without changing order
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { dog in orderedDogIds.contains(dog.id) }
        )

        if let dogs = try? modelContext.fetch(descriptor) {
            let orderedDogs = orderedDogIds.compactMap { id in dogs.first { $0.id == id } }
            let route = RouteOptimizer.optimizeRouteRespectingManualOrder(
                for: orderedDogs,
                manuallyOrdered: true
            )
            hike.route = route.pickups.compactMap { pickup in
                orderedDogs.first { $0.id == pickup.id }?.location
            }
            hike.totalDistance = route.totalDistance
        }

        hike.lastModifiedAt = Date()
    }

    /// Create new empty hike for a day
    ///
    /// - Parameter date: Date for new hike
    /// - Returns: Newly created hike
    func createNewHike(for date: Date) -> DailyHike {
        // Fetch existing hikes to determine next hike number
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!

        let descriptor = FetchDescriptor<DailyHike>(
            predicate: #Predicate { $0.date >= normalizedDate && $0.date < nextDay },
            sortBy: [SortDescriptor(\.hikeNumber)]
        )

        let existingHikes = (try? modelContext.fetch(descriptor)) ?? []
        let nextHikeNumber = (existingHikes.map { $0.hikeNumber }.max() ?? 0) + 1

        let newHike = DailyHike(
            date: normalizedDate,
            hikeNumber: nextHikeNumber,
            clusterMethod: "manual",  // Mark as manually created
            createdAt: Date(),
            lastModifiedAt: Date()
        )

        modelContext.insert(newHike)
        return newHike
    }

    /// Regroup all hikes for a day using geographic clustering
    ///
    /// Deletes existing hikes and recreates them with optimal geographic groupings.
    ///
    /// - Parameter date: Date to regroup
    func regroupAllHikes(for date: Date) {
        // Fetch existing hikes
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!

        let descriptor = FetchDescriptor<DailyHike>(
            predicate: #Predicate { $0.date >= normalizedDate && $0.date < nextDay },
            sortBy: [SortDescriptor(\.hikeNumber)]
        )

        guard let existingHikes = try? modelContext.fetch(descriptor) else { return }

        // Collect all participating dogs
        let allDogIds = Set(existingHikes.flatMap { $0.participations.map { $0.dogId } })
        let dogDescriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { dog in allDogIds.contains(dog.id) }
        )
        guard let allDogs = try? modelContext.fetch(dogDescriptor) else { return }

        // Delete existing hikes
        for hike in existingHikes {
            modelContext.delete(hike)
        }

        // Re-cluster and create new optimized hikes
        let clustered = HikeClusterer.clusterDogs(allDogs)

        for (index, group) in clustered.groups.enumerated() {
            let optimizedRoute = RouteOptimizer.optimizeRoute(for: group)
            let orderedDogs = optimizedRoute.pickups.compactMap { pickup in
                group.first { $0.id == pickup.id }
            }

            let newHike = DailyHike(
                date: normalizedDate,
                hikeNumber: index + 1,
                routeLatitudes: orderedDogs.compactMap { $0.location?.latitude },
                routeLongitudes: orderedDogs.compactMap { $0.location?.longitude },
                totalDistance: optimizedRoute.totalDistance,
                clusterMethod: clustered.method,
                wasAutoSplit: true,
                createdAt: Date(),
                lastModifiedAt: Date()
            )

            modelContext.insert(newHike)

            // Create participations
            for (dogIndex, dog) in orderedDogs.enumerated() {
                let participation = HikeParticipation(
                    dogId: dog.id,
                    dogName: dog.name,
                    pickupOrder: dogIndex + 1,
                    pickupLatitude: dog.locationLatitude,
                    pickupLongitude: dog.locationLongitude,
                    pickupAddress: dog.locationAddress,
                    rate: dog.paymentRate
                )
                participation.dailyHike = newHike
            }
        }
    }

    /// Split a hike into two separate hikes using geographic clustering
    /// Forces exactly 2 groups even if clustering suggests 1 is optimal
    ///
    /// - Parameter hike: Hike to split
    func splitHike(_ hike: DailyHike) {
        // Get all participating dogs
        let allDogIds = hike.participations.map { $0.dogId }
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { dog in allDogIds.contains(dog.id) }
        )
        guard let allDogs = try? modelContext.fetch(descriptor), allDogs.count > 1 else { return }

        // Use clustering to split into exactly 2 groups
        // Use ceiling division to ensure both groups together can hold all dogs
        let maxPerHike = (allDogs.count + 1) / 2
        let clustered = HikeClusterer.clusterDogs(allDogs, maxDogsPerHike: maxPerHike, allowOverflow: true)

        // Ensure we get exactly 2 groups (if clustering returned 1, split manually)
        var groups = clustered.groups
        if groups.count == 1 {
            // Manual split: divide dogs roughly by geographic midpoint
            let sorted = allDogs.sorted { dog1, dog2 in
                (dog1.location?.latitude ?? 0) < (dog2.location?.latitude ?? 0)
            }
            let midpoint = sorted.count / 2
            groups = [
                Array(sorted[..<midpoint]),
                Array(sorted[midpoint...])
            ]
        } else if groups.count > 2 {
            // Merge smallest groups until we have exactly 2
            // This shouldn't happen with proper maxPerHike, but handle it safely
            while groups.count > 2 {
                groups = groups.sorted { $0.count > $1.count }
                let smallest = groups.removeLast()
                groups[groups.count - 1].append(contentsOf: smallest)
            }
        }

        guard groups.count == 2, !groups[0].isEmpty, !groups[1].isEmpty else { return }

        // Keep first group in current hike
        let keepGroup = groups[0]
        let moveGroup = groups[1]

        // Remove all participations from current hike
        for participation in hike.participations {
            modelContext.delete(participation)
        }

        // Re-add the "keep" group to current hike
        let keepOptimized = RouteOptimizer.optimizeRoute(for: keepGroup)
        let keepOrdered = keepOptimized.pickups.compactMap { pickup in
            keepGroup.first { $0.id == pickup.id }
        }

        for (index, dog) in keepOrdered.enumerated() {
            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: index + 1,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate
            )
            participation.dailyHike = hike
        }

        hike.route = keepOptimized.pickups.compactMap { pickup in
            keepGroup.first { $0.id == pickup.id }?.location
        }
        hike.totalDistance = keepOptimized.totalDistance
        hike.lastModifiedAt = Date()

        // Create new hike for the "move" group
        let normalizedDate = Calendar.current.startOfDay(for: hike.date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!

        let hikeDescriptor = FetchDescriptor<DailyHike>(
            predicate: #Predicate { $0.date >= normalizedDate && $0.date < nextDay },
            sortBy: [SortDescriptor(\.hikeNumber)]
        )

        let existingHikes = (try? modelContext.fetch(hikeDescriptor)) ?? []
        let nextHikeNumber = (existingHikes.map { $0.hikeNumber }.max() ?? 0) + 1

        let moveOptimized = RouteOptimizer.optimizeRoute(for: moveGroup)
        let moveOrdered = moveOptimized.pickups.compactMap { pickup in
            moveGroup.first { $0.id == pickup.id }
        }

        let newHike = DailyHike(
            date: normalizedDate,
            hikeNumber: nextHikeNumber,
            routeLatitudes: moveOrdered.compactMap { $0.location?.latitude },
            routeLongitudes: moveOrdered.compactMap { $0.location?.longitude },
            totalDistance: moveOptimized.totalDistance,
            clusterMethod: "auto_geographic",
            wasAutoSplit: true,
            createdAt: Date(),
            lastModifiedAt: Date()
        )

        modelContext.insert(newHike)

        for (index, dog) in moveOrdered.enumerated() {
            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: index + 1,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate
            )
            participation.dailyHike = newHike
        }
    }

    /// Create a second hike with a specific dog from the first hike
    /// Used when user drags a dog to the drop zone to manually split
    ///
    /// - Parameters:
    ///   - dogId: The dog to move to the second hike
    ///   - sourceHike: The hike to remove the dog from
    func createSecondHike(with dogId: UUID, from sourceHike: DailyHike) {
        // Fetch the dog
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { $0.id == dogId }
        )
        guard let dog = try? modelContext.fetch(descriptor).first else { return }

        // Remove the dog from the source hike
        if let participation = sourceHike.participations.first(where: { $0.dogId == dogId }) {
            modelContext.delete(participation)
        }

        // Recalculate route for source hike
        recalculateRoute(for: sourceHike)

        // Create new second hike with just this dog
        let normalizedDate = Calendar.current.startOfDay(for: sourceHike.date)

        let newHike = DailyHike(
            date: normalizedDate,
            hikeNumber: 2,  // Always hike number 2 (since we're creating from the only hike)
            routeLatitudes: dog.location.map { [$0.latitude] } ?? [],
            routeLongitudes: dog.location.map { [$0.longitude] } ?? [],
            totalDistance: 0,  // Single pickup, no distance
            clusterMethod: "Manual split",
            wasAutoSplit: false,
            createdAt: Date(),
            lastModifiedAt: Date()
        )

        modelContext.insert(newHike)

        let participation = HikeParticipation(
            dogId: dog.id,
            dogName: dog.name,
            pickupOrder: 1,
            pickupLatitude: dog.locationLatitude,
            pickupLongitude: dog.locationLongitude,
            pickupAddress: dog.locationAddress,
            rate: dog.paymentRate
        )
        participation.dailyHike = newHike
    }
}
