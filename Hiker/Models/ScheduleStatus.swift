//
//  ScheduleStatus.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation

enum ScheduleStatus: String, Codable {
    case scheduled      // Dog is scheduled
    case away          // Dog is away/unavailable
    case injured       // Dog is injured/off
    case cancelled     // Hike was cancelled
    case rescheduled   // Rescheduled to different day

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .away: return "Away"
        case .injured: return "Injured"
        case .cancelled: return "Cancelled"
        case .rescheduled: return "Rescheduled"
        }
    }
}
