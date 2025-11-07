//
//  Date+Extensions.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation

extension Date {
    /// Returns the start of the day (midnight) for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the start of the week (Monday at midnight) for this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns the day of the week as a DayOfWeek enum (Monday-Friday only)
    var dayOfWeek: DayOfWeek? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)

        // weekday: 1 = Sunday, 2 = Monday, ..., 6 = Friday, 7 = Saturday
        switch weekday {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return nil  // Weekend
        }
    }

    /// Returns true if this date is a weekday (Monday-Friday)
    var isWeekday: Bool {
        dayOfWeek != nil
    }

    /// Returns true if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns the date for a specific day of the week in the same week
    func date(for dayOfWeek: DayOfWeek) -> Date {
        let calendar = Calendar.current
        let monday = startOfWeek

        // DayOfWeek.monday = 1, so offset is 0
        // DayOfWeek.friday = 5, so offset is 4
        let offset = dayOfWeek.rawValue - 1

        return calendar.date(byAdding: .day, value: offset, to: monday) ?? self
    }

    /// Returns an array of dates for all weekdays (Mon-Fri) in the same week
    var weekdaysInWeek: [Date] {
        DayOfWeek.allCases.map { date(for: $0) }
    }

    /// Add days to a date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add weeks to a date
    func addingWeeks(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }

    /// Format as "Monday, Nov 7"
    var mediumDateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// Format as "Mon"
    var shortDayString: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    /// Format as "Nov 7"
    var shortDateString: String {
        formatted(.dateTime.month(.abbreviated).day())
    }
}

extension Calendar {
    /// Check if two dates are in the same week
    func isSameWeek(_ date1: Date, as date2: Date) -> Bool {
        let components1 = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date1)
        let components2 = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date2)
        return components1.yearForWeekOfYear == components2.yearForWeekOfYear &&
               components1.weekOfYear == components2.weekOfYear
    }

    /// Get the number of days between two dates
    func daysBetween(_ start: Date, and end: Date) -> Int {
        dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day ?? 0
    }
}
