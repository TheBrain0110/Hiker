//
//  DateExtensionTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
@testable import Hiker

struct DateExtensionTests {

    // MARK: - Test Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    // MARK: - dayOfWeek Tests

    @Test("Monday returns .monday")
    func testMondayReturnsMonday() {
        // December 15, 2025 is a Monday
        let monday = makeDate(year: 2025, month: 12, day: 15)
        #expect(monday.dayOfWeek == .monday)
    }

    @Test("Tuesday returns .tuesday")
    func testTuesdayReturnsTuesday() {
        let tuesday = makeDate(year: 2025, month: 12, day: 16)
        #expect(tuesday.dayOfWeek == .tuesday)
    }

    @Test("Wednesday returns .wednesday")
    func testWednesdayReturnsWednesday() {
        let wednesday = makeDate(year: 2025, month: 12, day: 17)
        #expect(wednesday.dayOfWeek == .wednesday)
    }

    @Test("Thursday returns .thursday")
    func testThursdayReturnsThursday() {
        let thursday = makeDate(year: 2025, month: 12, day: 18)
        #expect(thursday.dayOfWeek == .thursday)
    }

    @Test("Friday returns .friday")
    func testFridayReturnsFriday() {
        let friday = makeDate(year: 2025, month: 12, day: 19)
        #expect(friday.dayOfWeek == .friday)
    }

    @Test("Saturday returns nil")
    func testSaturdayReturnsNil() {
        let saturday = makeDate(year: 2025, month: 12, day: 20)
        #expect(saturday.dayOfWeek == nil)
    }

    @Test("Sunday returns nil")
    func testSundayReturnsNil() {
        let sunday = makeDate(year: 2025, month: 12, day: 21)
        #expect(sunday.dayOfWeek == nil)
    }

    // MARK: - isWeekday Tests

    @Test("Weekdays return true for isWeekday")
    func testWeekdaysReturnTrueForIsWeekday() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let friday = makeDate(year: 2025, month: 12, day: 19)

        #expect(monday.isWeekday == true)
        #expect(friday.isWeekday == true)
    }

    @Test("Weekend returns false for isWeekday")
    func testWeekendReturnsFalseForIsWeekday() {
        let saturday = makeDate(year: 2025, month: 12, day: 20)
        let sunday = makeDate(year: 2025, month: 12, day: 21)

        #expect(saturday.isWeekday == false)
        #expect(sunday.isWeekday == false)
    }

    // MARK: - startOfDay Tests

    @Test("startOfDay strips time component")
    func testStartOfDayStripsTimeComponent() {
        let dateWithTime = makeDate(year: 2025, month: 12, day: 15, hour: 14, minute: 30)
        let startOfDay = dateWithTime.startOfDay

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)

        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("startOfDay preserves date")
    func testStartOfDayPreservesDate() {
        let date = makeDate(year: 2025, month: 12, day: 15, hour: 14, minute: 30)
        let startOfDay = date.startOfDay

        let calendar = Calendar.current
        let originalComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let startComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)

        #expect(originalComponents.year == startComponents.year)
        #expect(originalComponents.month == startComponents.month)
        #expect(originalComponents.day == startComponents.day)
    }

    // MARK: - startOfWeek Tests

    @Test("startOfWeek returns Monday for a Monday")
    func testStartOfWeekForMonday() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let startOfWeek = monday.startOfWeek

        #expect(startOfWeek.dayOfWeek == .monday)
    }

    @Test("startOfWeek returns Monday for a Friday")
    func testStartOfWeekForFriday() {
        let friday = makeDate(year: 2025, month: 12, day: 19)
        let startOfWeek = friday.startOfWeek

        // Should be the Monday of that week (Dec 15)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: startOfWeek)

        #expect(components.day == 15)
        #expect(startOfWeek.dayOfWeek == .monday)
    }

    @Test("startOfWeek returns Monday for a Sunday")
    func testStartOfWeekForSunday() {
        let sunday = makeDate(year: 2025, month: 12, day: 21)
        let startOfWeek = sunday.startOfWeek

        // Should be the Monday of that week (Dec 15)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: startOfWeek)

        #expect(components.day == 15)
    }

    // MARK: - date(for:) Tests

    @Test("date(for:) returns correct weekday in same week")
    func testDateForDayOfWeek() {
        let monday = makeDate(year: 2025, month: 12, day: 15)

        let wednesday = monday.date(for: .wednesday)
        let friday = monday.date(for: .friday)

        let calendar = Calendar.current

        let wedComponents = calendar.dateComponents([.day], from: wednesday)
        let friComponents = calendar.dateComponents([.day], from: friday)

        #expect(wedComponents.day == 17) // Dec 17, 2025
        #expect(friComponents.day == 19) // Dec 19, 2025
    }

    @Test("date(for:) from Friday still returns same week")
    func testDateForDayOfWeekFromFriday() {
        let friday = makeDate(year: 2025, month: 12, day: 19)

        let monday = friday.date(for: .monday)
        let calendar = Calendar.current
        let monComponents = calendar.dateComponents([.day], from: monday)

        #expect(monComponents.day == 15) // Dec 15, 2025 (same week's Monday)
    }

    // MARK: - weekdaysInWeek Tests

    @Test("weekdaysInWeek returns 5 dates (Mon-Fri)")
    func testWeekdaysInWeekReturns5Dates() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let weekdays = monday.weekdaysInWeek

        #expect(weekdays.count == 5)
    }

    @Test("weekdaysInWeek contains all weekdays")
    func testWeekdaysInWeekContainsAllWeekdays() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let weekdays = monday.weekdaysInWeek

        let dayOfWeekValues = weekdays.compactMap { $0.dayOfWeek }

        #expect(dayOfWeekValues.contains(.monday))
        #expect(dayOfWeekValues.contains(.tuesday))
        #expect(dayOfWeekValues.contains(.wednesday))
        #expect(dayOfWeekValues.contains(.thursday))
        #expect(dayOfWeekValues.contains(.friday))
    }

    // MARK: - addingDays Tests

    @Test("addingDays adds positive days")
    func testAddingPositiveDays() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let wednesday = monday.addingDays(2)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: wednesday)

        #expect(components.day == 17)
    }

    @Test("addingDays handles negative days")
    func testAddingNegativeDays() {
        let wednesday = makeDate(year: 2025, month: 12, day: 17)
        let monday = wednesday.addingDays(-2)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: monday)

        #expect(components.day == 15)
    }

    @Test("addingDays crosses month boundary")
    func testAddingDaysCrossesMonthBoundary() {
        let dec31 = makeDate(year: 2025, month: 12, day: 31)
        let jan1 = dec31.addingDays(1)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: jan1)

        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    // MARK: - addingWeeks Tests

    @Test("addingWeeks adds weeks correctly")
    func testAddingWeeks() {
        let dec15 = makeDate(year: 2025, month: 12, day: 15)
        let dec22 = dec15.addingWeeks(1)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dec22)

        #expect(components.day == 22)
    }

    // MARK: - Calendar Extension Tests

    @Test("isSameWeek returns true for same week")
    func testIsSameWeekTrue() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let friday = makeDate(year: 2025, month: 12, day: 19)

        #expect(Calendar.current.isSameWeek(monday, as: friday) == true)
    }

    @Test("isSameWeek returns false for different weeks")
    func testIsSameWeekFalse() {
        let week1Monday = makeDate(year: 2025, month: 12, day: 15)
        let week2Monday = makeDate(year: 2025, month: 12, day: 22)

        #expect(Calendar.current.isSameWeek(week1Monday, as: week2Monday) == false)
    }

    @Test("daysBetween calculates correctly")
    func testDaysBetween() {
        let monday = makeDate(year: 2025, month: 12, day: 15)
        let friday = makeDate(year: 2025, month: 12, day: 19)

        let days = Calendar.current.daysBetween(monday, and: friday)

        #expect(days == 4)
    }

    @Test("daysBetween handles negative direction")
    func testDaysBetweenNegative() {
        let friday = makeDate(year: 2025, month: 12, day: 19)
        let monday = makeDate(year: 2025, month: 12, day: 15)

        let days = Calendar.current.daysBetween(friday, and: monday)

        #expect(days == -4)
    }

    @Test("daysBetween returns zero for same day")
    func testDaysBetweenSameDay() {
        let date1 = makeDate(year: 2025, month: 12, day: 15, hour: 9)
        let date2 = makeDate(year: 2025, month: 12, day: 15, hour: 17)

        let days = Calendar.current.daysBetween(date1, and: date2)

        #expect(days == 0)
    }
}
