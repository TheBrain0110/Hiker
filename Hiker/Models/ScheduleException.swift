//
//  ScheduleException.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData

@Model
final class ScheduleException {
    @Attribute(.unique) var id: UUID
    var dogId: UUID
    var weekStartDate: Date  // Monday of the week

    // Store day overrides as dictionary (day raw value -> status raw value)
    var dayOverridesData: [Int: String] = [:]

    var createdDate: Date

    init(
        id: UUID = UUID(),
        dogId: UUID,
        weekStartDate: Date,
        dayOverrides: [DayOfWeek: ScheduleStatus] = [:],
        createdDate: Date = Date()
    ) {
        self.id = id
        self.dogId = dogId
        self.weekStartDate = weekStartDate
        self.dayOverridesData = dayOverrides.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value.rawValue
        }
        self.createdDate = createdDate
    }

    // Computed property for easier access
    var dayOverrides: [DayOfWeek: ScheduleStatus] {
        get {
            dayOverridesData.reduce(into: [:]) { result, pair in
                guard let day = DayOfWeek(rawValue: pair.key),
                      let status = ScheduleStatus(rawValue: pair.value) else { return }
                result[day] = status
            }
        }
        set {
            dayOverridesData = newValue.reduce(into: [:]) { result, pair in
                result[pair.key.rawValue] = pair.value.rawValue
            }
        }
    }

    // Helper: Get status for a specific day
    func status(for day: DayOfWeek) -> ScheduleStatus? {
        dayOverrides[day]
    }

    // Helper: Set status for a specific day
    func setStatus(_ status: ScheduleStatus?, for day: DayOfWeek) {
        var overrides = dayOverrides
        overrides[day] = status
        dayOverrides = overrides
    }
}
