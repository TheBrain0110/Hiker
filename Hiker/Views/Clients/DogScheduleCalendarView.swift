//
//  DogScheduleCalendarView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct DogScheduleCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog

    // Query all data and filter by dog ID in computed properties
    @Query private var allOverrides: [ScheduleOverride]
    @Query private var allAttendances: [DogAttendance]
    @Query(sort: \CompletedHike.date, order: .reverse)
    private var completedHikes: [CompletedHike]

    @State private var currentMonth: Date = Date()

    private var calendar: Calendar {
        Calendar.current
    }

    // MARK: - Computed Filtered Data

    private var dogOverrides: [ScheduleOverride] {
        allOverrides.filter { $0.dogId == dog.id }
    }

    private var dogAttendances: [DogAttendance] {
        allAttendances.filter { $0.dogId == dog.id }
    }

    // MARK: - Body

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
                DogMonthGridView(
                    dog: dog,
                    month: currentMonth,
                    dogOverrides: dogOverrides,
                    dogAttendances: dogAttendances,
                    completedHikes: completedHikes,
                    onDateTap: handleDateTap
                )
                .padding()
            }
        }
    }

    // MARK: - Helper Methods

    private func moveMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func handleDateTap(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)

        // Don't allow editing past dates
        guard normalizedDate >= calendar.startOfDay(for: Date()) else { return }

        // Check for existing override
        if let existingOverride = dogOverrides.first(where: {
            calendar.isDate($0.date, inSameDayAs: normalizedDate)
        }) {
            // Toggle: Delete override (revert to regular schedule)
            modelContext.delete(existingOverride)
        } else {
            // Create new override
            let dayOfWeek = normalizedDate.dayOfWeek
            let isInRegularSchedule = dayOfWeek.map { dog.regularSchedule.contains($0) } ?? false

            let overrideType: OverrideType = isInRegularSchedule ? .isAbsent : .isPresent
            let override = ScheduleOverride(dogId: dog.id, date: normalizedDate, type: overrideType)
            modelContext.insert(override)
        }

        // Haptic feedback on iOS
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Dog Month Grid View

private struct DogMonthGridView: View {
    let dog: Dog
    let month: Date
    let dogOverrides: [ScheduleOverride]
    let dogAttendances: [DogAttendance]
    let completedHikes: [CompletedHike]
    let onDateTap: (Date) -> Void

    private var calendar: Calendar {
        Calendar.current
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
                    DogCalendarDayCell(
                        date: date,
                        dog: dog,
                        isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                        dogOverrides: dogOverrides,
                        dogAttendances: dogAttendances,
                        completedHikes: completedHikes,
                        onTap: onDateTap
                    )
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
}

// MARK: - Dog Calendar Day Cell

private struct DogCalendarDayCell: View {
    let date: Date
    let dog: Dog
    let isCurrentMonth: Bool
    let dogOverrides: [ScheduleOverride]
    let dogAttendances: [DogAttendance]
    let completedHikes: [CompletedHike]
    let onTap: (Date) -> Void

    private var calendar: Calendar {
        Calendar.current
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    private var isPast: Bool {
        calendar.startOfDay(for: date) < today
    }

    // MARK: - Schedule State Computation

    private var scheduleState: DogScheduleState {
        let normalizedDate = calendar.startOfDay(for: date)

        // Check if this is a past date
        let isPastDate = normalizedDate < today

        // Check for completed hike (past only)
        let isCompleted = isPastDate && dogAttendances.contains { attendance in
            guard let hikeDate = attendance.completedHike?.date else { return false }
            return calendar.isDate(hikeDate, inSameDayAs: normalizedDate)
        }

        // For future/today: check schedule
        var isScheduled = false
        var isAbsent = false
        var hasOverride = false

        if !isPastDate {
            // Check for override first
            if let override = dogOverrides.first(where: {
                calendar.isDate($0.date, inSameDayAs: normalizedDate)
            }) {
                hasOverride = true
                isScheduled = (override.type == .isPresent)
                isAbsent = (override.type == .isAbsent)
            } else {
                // No override: check regular schedule
                if let dayOfWeek = normalizedDate.dayOfWeek {
                    isScheduled = dog.regularSchedule.contains(dayOfWeek)
                }
            }
        }

        return DogScheduleState(
            isScheduled: isScheduled,
            isAbsent: isAbsent,
            isCompleted: isCompleted,
            isPast: isPastDate,
            isToday: isToday,
            hasOverride: hasOverride
        )
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayFormatter.string(from: date))
                .font(isToday ? .headline : .subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isCurrentMonth ? .primary : .secondary)

            // Indicators
            HStack(spacing: 3) {
                if scheduleState.isCompleted {
                    // Green dot for completed hikes
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                } else if scheduleState.isAbsent {
                    // Red X for override absence
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                } else if scheduleState.isScheduled {
                    // Blue dot for override presence, orange for regular schedule
                    Circle()
                        .fill(scheduleState.hasOverride ? .blue : .orange)
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(date)
        }
    }
}

// MARK: - Dog Schedule State

private struct DogScheduleState {
    let isScheduled: Bool      // Regular schedule OR override.isPresent
    let isAbsent: Bool         // Override.isAbsent exists
    let isCompleted: Bool      // DogAttendance exists (past only)
    let isPast: Bool
    let isToday: Bool
    let hasOverride: Bool      // Used to distinguish blue (override) vs orange (regular)
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Dog.self, Client.self,
        configurations: config
    )

    let client = Client(ownerName: "Test Owner", address: "123 Test St")
    let dog = Dog(
        name: "Buddy",
        client: client,
        locationAddress: "123 Test St",
        regularSchedule: [.monday, .wednesday, .friday]
    )

    container.mainContext.insert(client)
    container.mainContext.insert(dog)

    return DogScheduleCalendarView(dog: dog)
        .modelContainer(container)
        .frame(height: 380)
}
