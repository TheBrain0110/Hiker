//
//  DayOfWeekTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
@testable import Hiker

struct DayOfWeekTests {

    @Test("DayOfWeek raw values are 1-5")
    func testDayOfWeekRawValues() {
        #expect(DayOfWeek.monday.rawValue == 1)
        #expect(DayOfWeek.tuesday.rawValue == 2)
        #expect(DayOfWeek.wednesday.rawValue == 3)
        #expect(DayOfWeek.thursday.rawValue == 4)
        #expect(DayOfWeek.friday.rawValue == 5)
    }

    @Test("DayOfWeek name property returns full name")
    func testDayOfWeekName() {
        #expect(DayOfWeek.monday.name == "Monday")
        #expect(DayOfWeek.tuesday.name == "Tuesday")
        #expect(DayOfWeek.wednesday.name == "Wednesday")
        #expect(DayOfWeek.thursday.name == "Thursday")
        #expect(DayOfWeek.friday.name == "Friday")
    }

    @Test("DayOfWeek shortName property returns abbreviation")
    func testDayOfWeekShortName() {
        #expect(DayOfWeek.monday.shortName == "Mon")
        #expect(DayOfWeek.tuesday.shortName == "Tue")
        #expect(DayOfWeek.wednesday.shortName == "Wed")
        #expect(DayOfWeek.thursday.shortName == "Thu")
        #expect(DayOfWeek.friday.shortName == "Fri")
    }

    @Test("DayOfWeek allCases contains 5 days")
    func testDayOfWeekAllCases() {
        #expect(DayOfWeek.allCases.count == 5)
    }

    @Test("DayOfWeek id is same as rawValue")
    func testDayOfWeekId() {
        for day in DayOfWeek.allCases {
            #expect(day.id == day.rawValue)
        }
    }

    @Test("DayOfWeek can be initialized from raw value")
    func testDayOfWeekInitFromRawValue() {
        #expect(DayOfWeek(rawValue: 1) == .monday)
        #expect(DayOfWeek(rawValue: 3) == .wednesday)
        #expect(DayOfWeek(rawValue: 5) == .friday)
        #expect(DayOfWeek(rawValue: 0) == nil)
        #expect(DayOfWeek(rawValue: 6) == nil)
    }
}
