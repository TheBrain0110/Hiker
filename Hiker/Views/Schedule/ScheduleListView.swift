//
//  ScheduleListView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct ScheduleListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CompletedHike.date, order: .reverse)
    private var completedHikes: [CompletedHike]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var dailySchedules: [Date: DailyHike] = [:]

    private let daysBack = 30
    private let daysForward = 60

    // Generate array of all dates to display
    private var allDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dates: [Date] = []

        // Past days (newest first)
        for i in (1...daysBack).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(date)
            }
        }

        // Today
        dates.append(today)

        // Future days
        for i in 1...daysForward {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }

        return dates
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(allDates, id: \.self) { date in
                    DayRow(
                        date: date,
                        isToday: Calendar.current.isDate(date, inSameDayAs: today),
                        completedHikes: completedHikesFor(date: date),
                        scheduledDogs: scheduledDogsFor(date: date)
                    )
                    .id(date)
                    .listRowBackground(
                        Calendar.current.isDate(date, inSameDayAs: today) ?
                        Color.blue.opacity(0.1) : nil
                    )
                }
            }
            .listStyle(.plain)
            .onAppear {
                loadSchedules()
                // Scroll to today on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
            .onChange(of: activeDogs) {
                loadSchedules()
            }
            .onChange(of: scheduleOverrides) {
                loadSchedules()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSchedules() {
        let manager = DailyHikeManager(modelContext: modelContext)

        for date in allDates {
            let schedule = manager.dailySchedule(for: date)
            dailySchedules[date] = schedule
        }
    }

    private func completedHikesFor(date: Date) -> [CompletedHike] {
        let calendar = Calendar.current
        return completedHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }

    private func scheduledDogsFor(date: Date) -> [Dog] {
        guard let schedule = dailySchedules[date] else { return [] }

        // Combine all dogs from both hikes
        var allDogs = schedule.hike1?.dogs ?? []
        if let hike2Dogs = schedule.hike2?.dogs {
            allDogs.append(contentsOf: hike2Dogs)
        }

        return allDogs
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Client.self, Dog.self, CompletedHike.self, DogAttendance.self,
        configurations: config
    )

    return NavigationStack {
        ScheduleListView()
    }
    .modelContainer(container)
}
