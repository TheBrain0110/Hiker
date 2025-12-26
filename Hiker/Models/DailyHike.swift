//
//  DailyHike.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

/// Reason why a hike is marked as stale and needs attention
enum StaleReason: String, Codable {
    /// Dogs were manually added or removed - just need to re-optimize pickup route
    case routeNeedsOptimization
    /// A dog's regular schedule or override changed - need to sync dog list with schedule
    case scheduleChanged
}

/// Unified persistent model for hike lifecycle: planned → customized → completed
@Model
final class DailyHike {
    @Attribute(.unique) var id: UUID

    // Core identity (composite key: date + hikeNumber)
    var date: Date                          // Day of hike (normalized to startOfDay)
    var hikeNumber: Int                     // 1 or 2

    // Lifecycle state
    var completedAt: Date?                  // nil = planned, set = completed
    var staleReasonRaw: String?             // Why hike needs attention (nil = not stale)

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
        staleReason: StaleReason? = nil,
        routeLatitudes: [Double] = [],
        routeLongitudes: [Double] = [],
        totalDistance: Double = 0,
        selectedTrailId: UUID? = nil,
        trailName: String? = nil,
        removedDogIds: [UUID] = [],
        removedDogNames: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.hikeNumber = hikeNumber
        self.completedAt = completedAt
        self.staleReasonRaw = staleReason?.rawValue
        self.routeLatitudes = routeLatitudes
        self.routeLongitudes = routeLongitudes
        self.totalDistance = totalDistance
        self.selectedTrailId = selectedTrailId
        self.trailName = trailName
        self.removedDogIds = removedDogIds
        self.removedDogNames = removedDogNames
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

    /// Type-safe access to the stale reason
    var staleReason: StaleReason? {
        get { staleReasonRaw.flatMap { StaleReason(rawValue: $0) } }
        set { staleReasonRaw = newValue?.rawValue }
    }

    /// Convenience property for backward compatibility
    var isStale: Bool {
        staleReason != nil
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
