//
//  DailyHike.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

/// Unified persistent model for hike lifecycle: planned → customized → completed
@Model
final class DailyHike {
    @Attribute(.unique) var id: UUID

    // Core identity (composite key: date + hikeNumber)
    var date: Date                          // Day of hike (normalized to startOfDay)
    var hikeNumber: Int                     // 1 or 2

    // Lifecycle state
    var completedAt: Date?                  // nil = planned, set = completed

    // Cached route (from optimization)
    var routeLatitudes: [Double] = []
    var routeLongitudes: [Double] = []
    var totalDistance: Double = 0

    // Trail selection
    var selectedTrailId: UUID?              // User-selected or auto-suggested
    var trailName: String?                  // Denormalized for history

    // Override tracking (for completed hikes - dogs that were removed via .isAbsent)
    var removedDogIds: [UUID] = []
    var removedDogNames: [String] = []

    // Clustering metadata
    var clusterMethod: String? = nil       // "auto_geographic", "manual", or nil (legacy)
    var suggestedMaxDogs: Int = 8          // Soft capacity limit (configurable)
    var wasAutoSplit: Bool = false         // Whether hike resulted from auto-clustering
    var hasManualRouteOrder: Bool = false  // Whether user manually reordered dogs

    // Metadata
    var notes: String?
    var createdAt: Date
    var lastModifiedAt: Date

    // Relationship to dog participation
    @Relationship(deleteRule: .cascade, inverse: \HikeParticipation.dailyHike)
    var participations: [HikeParticipation] = []

    init(
        id: UUID = UUID(),
        date: Date,
        hikeNumber: Int,
        completedAt: Date? = nil,
        routeLatitudes: [Double] = [],
        routeLongitudes: [Double] = [],
        totalDistance: Double = 0,
        selectedTrailId: UUID? = nil,
        trailName: String? = nil,
        removedDogIds: [UUID] = [],
        removedDogNames: [String] = [],
        clusterMethod: String? = nil,
        suggestedMaxDogs: Int = 8,
        wasAutoSplit: Bool = false,
        hasManualRouteOrder: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.hikeNumber = hikeNumber
        self.completedAt = completedAt
        self.routeLatitudes = routeLatitudes
        self.routeLongitudes = routeLongitudes
        self.totalDistance = totalDistance
        self.selectedTrailId = selectedTrailId
        self.trailName = trailName
        self.removedDogIds = removedDogIds
        self.removedDogNames = removedDogNames
        self.clusterMethod = clusterMethod
        self.suggestedMaxDogs = suggestedMaxDogs
        self.wasAutoSplit = wasAutoSplit
        self.hasManualRouteOrder = hasManualRouteOrder
        self.notes = notes
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
    }

    // MARK: - Computed Properties

    /// Reconstruct route coordinates from stored lat/lon arrays
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

    /// Whether hike has been marked complete
    var isCompleted: Bool {
        completedAt != nil
    }

    /// Whether hike is still in planned state
    var isPlanned: Bool {
        completedAt == nil
    }

    /// Number of dogs participating in this hike
    var dogCount: Int {
        participations.count
    }

    /// Participations sorted by pickup order
    var orderedParticipations: [HikeParticipation] {
        participations.sorted { $0.pickupOrder < $1.pickupOrder }
    }

    /// Text summary of dog names
    var dogsText: String {
        orderedParticipations.map { $0.dogName }.joined(separator: ", ")
    }

    /// Whether this hike has no dogs
    var isEmpty: Bool {
        participations.isEmpty
    }
}
