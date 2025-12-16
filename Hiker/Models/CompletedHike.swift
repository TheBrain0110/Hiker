//
//  CompletedHike.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class CompletedHike {
    @Attribute(.unique) var id: UUID
    var date: Date                          // Day hike occurred (normalized to startOfDay)
    var hikeNumber: Int                     // 1 or 2
    var completedAt: Date                   // Timestamp when marked complete

    // Store actual route taken as coordinate pairs
    var routeLatitudes: [Double] = []
    var routeLongitudes: [Double] = []

    // Trail information
    var trailLocationId: UUID?              // Link to HikingLocation
    var trailName: String?                  // Denormalized for history preservation

    // Metadata
    var totalDistance: Double               // Actual route distance
    var notes: String?                      // Post-hike notes

    // Schedule override tracking (dogs that were removed via .isAbsent override)
    var removedDogIds: [UUID] = []          // IDs of dogs with .isAbsent override
    var removedDogNames: [String] = []      // Denormalized names for history

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \DogAttendance.completedHike)
    var dogAttendances: [DogAttendance] = []

    init(
        id: UUID = UUID(),
        date: Date,
        hikeNumber: Int,
        completedAt: Date = Date(),
        routeLatitudes: [Double] = [],
        routeLongitudes: [Double] = [],
        trailLocationId: UUID? = nil,
        trailName: String? = nil,
        totalDistance: Double = 0,
        notes: String? = nil,
        removedDogIds: [UUID] = [],
        removedDogNames: [String] = []
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.hikeNumber = hikeNumber
        self.completedAt = completedAt
        self.routeLatitudes = routeLatitudes
        self.routeLongitudes = routeLongitudes
        self.trailLocationId = trailLocationId
        self.trailName = trailName
        self.totalDistance = totalDistance
        self.notes = notes
        self.removedDogIds = removedDogIds
        self.removedDogNames = removedDogNames
    }

    // Computed property: Reconstruct route coordinates
    var route: [CLLocationCoordinate2D] {
        get {
            zip(routeLatitudes, routeLongitudes).map { lat, lon in
                CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        set {
            routeLatitudes = newValue.map { $0.latitude }
            routeLongitudes = newValue.map { $0.longitude }
        }
    }

    var dogCount: Int {
        dogAttendances.count
    }
}
