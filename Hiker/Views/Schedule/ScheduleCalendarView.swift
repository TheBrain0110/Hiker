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

    @Query(sort: \DailyHike.date, order: .reverse)
    private var allDailyHikes: [DailyHike]

    private var completedHikes: [DailyHike] {
        allDailyHikes.filter { $0.isCompleted }
    }

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var currentMonth: Date = Date()

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
                    allDailyHikes: allDailyHikes,
                    completedHikes: completedHikes
                )
                .padding()
            }
        }
        .onAppear {
            loadHikesForMonth()
        }
        .onChange(of: currentMonth) {
            loadHikesForMonth()
        }
        // Note: Removed onChange handlers - stale flags handle schedule changes
    }

    // MARK: - Helper Methods

    private func moveMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func loadHikesForMonth() {
        // Only load today when first opening calendar view
        // The calendar will show indicators for existing hikes only
        // Other days load on-demand when user taps to view details
        let manager = DailyHikeManager(modelContext: modelContext)
        _ = manager.getDailyHikes(for: Date())
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

// MARK: - Month Grid View

struct MonthGridView: View {
    @Environment(\.modelContext) private var modelContext

    let month: Date
    let allDailyHikes: [DailyHike]
    let completedHikes: [DailyHike]

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
                        hikes: hikesFor(date: date),
                        completedHikes: completedHikesFor(date: date),
                        hasExpectedDogs: hasExpectedDogsFor(date: date)
                    )
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func hikesFor(date: Date) -> [DailyHike] {
        allDailyHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }

    private func completedHikesFor(date: Date) -> [DailyHike] {
        completedHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }

    private func hasExpectedDogsFor(date: Date) -> Bool {
        // If there are already hikes for this date, don't compute expected
        let existingHikes = hikesFor(date: date)
        if !existingHikes.isEmpty {
            return false  // Let the cell check actual hikes instead
        }

        // Compute ephemeral preview
        let manager = DailyHikeManager(modelContext: modelContext)
        let expectedDogs = manager.getExpectedDogs(for: date)
        return !expectedDogs.isEmpty
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isCurrentMonth: Bool
    let hikes: [DailyHike]
    let completedHikes: [DailyHike]
    let hasExpectedDogs: Bool  // Ephemeral preview from regular schedules

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private var hasScheduledDogs: Bool {
        // Check actual hikes first
        if hikes.contains(where: { $0.isPlanned && !$0.participations.isEmpty }) {
            return true
        }
        // Fall back to expected dogs (ephemeral preview)
        return hasExpectedDogs
    }

    private var hasCompletedHikes: Bool {
        !completedHikes.isEmpty
    }

    private var scheduleIndicatorColor: Color {
        // If there's a persisted hike, use orange
        if hikes.contains(where: { $0.isPlanned && !$0.participations.isEmpty }) {
            return .orange
        }
        // If it's just an ephemeral preview, use yellow
        if hasExpectedDogs {
            return .yellow
        }
        return .clear
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
                            .fill(scheduleIndicatorColor)
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
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return NavigationStack {
        ScheduleCalendarView()
    }
    .modelContainer(container)
}
