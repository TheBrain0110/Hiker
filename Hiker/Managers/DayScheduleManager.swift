//
//  DayScheduleManager.swift
//  Hiker
//
//  Created on 12/26/25.
//  Business logic for day schedule manipulation
//

import Foundation
import SwiftData

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

        // Add participation to first available planned hike
        if let targetHike = plannedHikes.first(where: { $0.participations.count < 8 }) {
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

            // Mark hike as stale since route needs recalculation
            // Don't downgrade from .scheduleChanged to .routeNeedsOptimization
            if targetHike.staleReason != .scheduleChanged {
                targetHike.staleReason = .routeNeedsOptimization
            }
            targetHike.lastModifiedAt = Date()
        }

        // Mark affected future hikes as stale
        let dailyHikeManager = DailyHikeManager(modelContext: modelContext)
        dailyHikeManager.markAffectedHikesStale(for: dog.id, after: date)
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

        // Mark this hike as stale since route needs recalculation
        // Don't downgrade from .scheduleChanged to .routeNeedsOptimization
        if hike.staleReason != .scheduleChanged {
            hike.staleReason = .routeNeedsOptimization
        }
        hike.lastModifiedAt = Date()

        // Mark affected future hikes as stale
        let dailyHikeManager = DailyHikeManager(modelContext: modelContext)
        dailyHikeManager.markAffectedHikesStale(for: dog.id, after: date)
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
            hike.staleReason = nil
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
        hike.staleReason = nil
        hike.lastModifiedAt = Date()
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
}
