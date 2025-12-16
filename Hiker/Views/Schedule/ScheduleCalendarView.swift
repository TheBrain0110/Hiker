//
//  ScheduleCalendarView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct ScheduleCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CompletedHike.date, order: .reverse)
    private var completedHikes: [CompletedHike]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var currentMonth: Date = Date()
    @State private var dailySchedules: [Date: DailyHike] = [:]

    private var calendar: Calendar {
        Calendar.current
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation
            MonthNavigationHeader(
                currentMonth: $currentMonth,
                onPrevious: { moveMonth(by: -1) },
                onNext: { moveMonth(by: 1) }
            )
            .padding()

            Divider()

            // Weekday headers
            WeekdayHeader()
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Calendar grid
            ScrollView {
                MonthGridView(
                    month: currentMonth,
                    dailySchedules: dailySchedules,
                    completedHikes: completedHikes
                )
                .padding()
            }
        }
        .onAppear {
            loadSchedules()
        }
        .onChange(of: currentMonth) {
            loadSchedules()
        }
        .onChange(of: activeDogs) {
            loadSchedules()
        }
        .onChange(of: scheduleOverrides) {
            loadSchedules()
        }
    }

    // MARK: - Helper Methods

    private func moveMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func loadSchedules() {
        let manager = DailyHikeManager(modelContext: modelContext)

        // Load schedules for the entire month
        let monthDays = getDaysInMonth(currentMonth)
        for date in monthDays {
            let schedule = manager.dailySchedule(for: date)
            dailySchedules[date] = schedule
        }
    }

    private func getDaysInMonth(_ date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }
}

// MonthNavigationHeader and WeekdayHeader now in Views/Components/

// MARK: - Month Grid View

struct MonthGridView: View {
    let month: Date
    let dailySchedules: [Date: DailyHike]
    let completedHikes: [CompletedHike]

    private var calendar: Calendar {
        Calendar.current
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    // Get all dates to display (including leading/trailing days from adjacent months)
    private var calendarDates: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        // Get first day of month's weekday (0 = Sunday, 6 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1

        // Get number of days in month
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count
        else { return [] }

        var dates: [Date?] = []

        // Add leading empty cells
        for _ in 0..<firstWeekday {
            dates.append(nil)
        }

        // Add days of month
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                dates.append(date)
            }
        }

        return dates
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(Array(calendarDates.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    CalendarDayCell(
                        date: date,
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                        schedule: dailySchedules[date],
                        completedHikes: completedHikesFor(date: date)
                    )
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func completedHikesFor(date: Date) -> [CompletedHike] {
        completedHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isCurrentMonth: Bool
    let schedule: DailyHike?
    let completedHikes: [CompletedHike]

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private var hasScheduledDogs: Bool {
        guard let schedule = schedule else { return false }
        return !schedule.isEmpty
    }

    private var hasCompletedHikes: Bool {
        !completedHikes.isEmpty
    }

    var body: some View {
        NavigationLink {
            DayDetailView(date: date)
        } label: {
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date))
                    .font(isToday ? .headline : .subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isCurrentMonth ? .primary : .secondary)

                // Indicators
                HStack(spacing: 3) {
                    if hasCompletedHikes {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    } else if hasScheduledDogs {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 10)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return NavigationStack {
        ScheduleCalendarView()
    }
    .modelContainer(container)
}
