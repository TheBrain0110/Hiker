//
//  DailyHikeManager.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

/// Manages daily hike schedules by computing which dogs should be picked up
/// based on their regular schedules and any exceptions for the week
@MainActor
class DailyHikeManager {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Compute the daily schedule for a specific date
    func dailySchedule(for date: Date = Date()) -> DailyHike {
        // Get the day of week
        guard let dayOfWeek = date.dayOfWeek else {
            // Weekend - no hikes
            return DailyHike(date: date, hikes: [])
        }

        // Get all active dogs scheduled for this day
        let scheduledDogs = getScheduledDogs(for: date, dayOfWeek: dayOfWeek)

        // Group dogs into hikes (max 8 per hike)
        let groupedDogs = groupIntoHikes(scheduledDogs)

        // Get available hiking locations
        let hikingLocations = fetchHikingLocations()

        // Create hikes with optimized routes
        let hikes = groupedDogs.enumerated().map { index, dogs in
            createHike(
                number: index + 1,
                dogs: dogs,
                hikingLocations: hikingLocations
            )
        }

        return DailyHike(date: date, hikes: hikes)
    }

    /// Get all dogs scheduled for a specific week
    func scheduledDogs(for weekStartDate: Date) -> [DayOfWeek: [Dog]] {
        var result: [DayOfWeek: [Dog]] = [:]

        for day in DayOfWeek.allCases {
            let date = weekStartDate.date(for: day)
            let dogs = getScheduledDogs(for: date, dayOfWeek: day)
            result[day] = dogs
        }

        return result
    }

    // MARK: - Private Helpers

    /// Get all dogs that should be scheduled for a specific date
    private func getScheduledDogs(for date: Date, dayOfWeek: DayOfWeek) -> [Dog] {
        // Fetch all active dogs
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.name)]
        )

        guard let allDogs = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Filter dogs based on regular schedule and exceptions
        return allDogs.filter { dog in
            isScheduled(dog: dog, on: date, dayOfWeek: dayOfWeek)
        }
    }

    /// Check if a dog is scheduled for a specific date
    private func isScheduled(dog: Dog, on date: Date, dayOfWeek: DayOfWeek) -> Bool {
        // First check for exceptions for this week
        let weekStart = date.startOfWeek

        let exceptionDescriptor = FetchDescriptor<ScheduleException>(
            predicate: #Predicate<ScheduleException> { exception in
                exception.dogId == dog.id &&
                exception.weekStartDate == weekStart
            }
        )

        if let exceptions = try? modelContext.fetch(exceptionDescriptor),
           let exception = exceptions.first,
           let status = exception.status(for: dayOfWeek) {
            // Exception exists for this day
            switch status {
            case .scheduled:
                return true
            case .away, .injured, .cancelled:
                return false
            case .rescheduled:
                // For now, treat rescheduled as not scheduled
                // (proper handling would need to check where it was rescheduled to)
                return false
            }
        }

        // No exception - use regular schedule
        return dog.isScheduledOn(dayOfWeek)
    }

    /// Group dogs into hikes (max 8 per hike, 2 hikes max)
    private func groupIntoHikes(_ dogs: [Dog]) -> [[Dog]] {
        let maxDogsPerHike = 8
        let maxHikes = 2

        // If 8 or fewer dogs, one hike
        if dogs.count <= maxDogsPerHike {
            return [dogs]
        }

        // If more than 8 but less than or equal to 16, split into two balanced hikes
        if dogs.count <= maxDogsPerHike * maxHikes {
            let midpoint = dogs.count / 2
            let hike1 = Array(dogs[..<midpoint])
            let hike2 = Array(dogs[midpoint...])
            return [hike1, hike2]
        }

        // If more than 16, take first 16 and split evenly
        // (This shouldn't happen in normal operation, but handle gracefully)
        let limitedDogs = Array(dogs.prefix(maxDogsPerHike * maxHikes))
        let midpoint = limitedDogs.count / 2
        let hike1 = Array(limitedDogs[..<midpoint])
        let hike2 = Array(limitedDogs[midpoint...])
        return [hike1, hike2]
    }

    /// Create a hike with optimized route and suggested trail
    private func createHike(
        number: Int,
        dogs: [Dog],
        hikingLocations: [HikingLocation]
    ) -> DailyHike.Hike {
        guard !dogs.isEmpty else {
            return DailyHike.Hike(
                number: number,
                dogs: [],
                route: [],
                totalDistance: 0,
                suggestedTrail: nil
            )
        }

        // Optimize the pickup route
        let optimizedRoute = RouteOptimizer.optimizeRoute(for: dogs)

        // Build route coordinates
        let routeCoordinates = optimizedRoute.pickups.compactMap { pickup in
            dogs.first { $0.id == pickup.id }?.location
        }

        // Suggest a trail based on the last pickup's region
        let suggestedTrail = suggestTrail(
            for: dogs,
            routeCoordinates: routeCoordinates,
            hikingLocations: hikingLocations
        )

        // Use optimized dog order
        let orderedDogs = optimizedRoute.pickups.compactMap { pickup in
            dogs.first { $0.id == pickup.id }
        }

        return DailyHike.Hike(
            number: number,
            dogs: orderedDogs,
            route: routeCoordinates,
            totalDistance: optimizedRoute.totalDistance,
            suggestedTrail: suggestedTrail
        )
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
