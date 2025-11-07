//
//  DailyHike.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import CoreLocation

/// Represents a computed daily schedule (not persisted)
/// This is generated from Dog regular schedules + ScheduleExceptions
struct DailyHike: Identifiable {
    let id = UUID()
    let date: Date
    let hikes: [Hike]

    /// Individual hike within a day
    struct Hike: Identifiable {
        let id = UUID()
        let number: Int                    // 1 or 2
        let dogs: [Dog]                    // Dogs in this hike (ordered)
        let route: [CLLocationCoordinate2D]  // Pickup coordinates in order
        let totalDistance: CLLocationDistance
        let suggestedTrail: HikingLocation?

        var dogsText: String {
            dogs.map { $0.name }.joined(separator: ", ")
        }

        var isEmpty: Bool {
            dogs.isEmpty
        }

        var dogCount: Int {
            dogs.count
        }
    }

    /// Convenience accessors
    var hike1: Hike? {
        hikes.first { $0.number == 1 }
    }

    var hike2: Hike? {
        hikes.first { $0.number == 2 }
    }

    var totalDogs: Int {
        hikes.reduce(0) { $0 + $1.dogs.count }
    }

    var isEmpty: Bool {
        totalDogs == 0
    }
}
