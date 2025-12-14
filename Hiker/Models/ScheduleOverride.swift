//
//  ScheduleOverride.swift
//  Hiker
//
//  Created by Gemini on 12/14/25.
//

import Foundation
import SwiftData

@Model
final class ScheduleOverride {
    @Attribute(.unique) var id: UUID
    var dogId: UUID
    var date: Date
    
    // Stored as String for persistence, accessed via computed property
    private var typeRaw: String
    var note: String?

    init(id: UUID = UUID(), dogId: UUID, date: Date, type: OverrideType, note: String? = nil) {
        self.id = id
        self.dogId = dogId
        self.date = date
        self.typeRaw = type.rawValue
        self.note = note
    }
    
    var type: OverrideType {
        get { OverrideType(rawValue: typeRaw) ?? .isAbsent }
        set { typeRaw = newValue.rawValue }
    }
}

enum OverrideType: String, Codable {
    case isPresent // Dog is explicitly added/rescheduled to this day
    case isAbsent  // Dog is explicitly removed/away from this day
}
